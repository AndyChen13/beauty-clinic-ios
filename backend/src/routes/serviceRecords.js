const express = require('express');
const prisma = require('../config/database');
const { authMiddleware, requireAdmin } = require('../middleware/auth');

const router = express.Router();

// Convert snake_case keys from iOS to camelCase for Prisma
function snakeToCamelKeys(obj) {
  if (!obj || typeof obj !== 'object') return obj;
  const map = {
    customer_id: 'customerId',
    transaction_id: 'transactionId',
    service_date: 'serviceDate',
    service_details: 'serviceDetails',
    operator_id: 'operatorId',
    operator_name: 'operatorName',
    operator_phone: 'operatorPhone',
    body_part: 'bodyPart',
    customer_feedback: 'customerFeedback',
    extra_payment: 'extraPayment',
    extra_payment_note: 'extraPaymentNote',
    sessions_used: 'sessionsUsed',
    remaining_sessions: 'remainingSessions',
    created_at: 'createdAt',
    rebate_amount: 'rebateAmount',
    branch: 'branch',
    updated_at: 'updatedAt'
  };
  const result = {};
  for (const [key, value] of Object.entries(obj)) {
    result[map[key] || key] = value;
  }
  return result;
}


// Helper: get/create placeholder package for service record extra payments
async function getOrCreateCustomPackage() {
  let customPackage = await prisma.servicePackage.findFirst({
    where: { name: '自定义项目' },
  });
  if (!customPackage) {
    customPackage = await prisma.servicePackage.create({
      data: {
        name: '自定义项目',
        description: '自定义成交项目占位套餐',
        totalSessions: 0,
        durationMinutes: 0,
        price: 0,
        isActive: false,
      },
    });
  }
  return customPackage.id;
}

router.use(authMiddleware);

// GET /api/service-records - List service records
router.get('/', async (req, res) => {
  try {
    const { customerId } = req.query;
    const where = {};
    if (customerId) where.customerId = customerId;

    // Join through customer for permission check
    if (req.user.role === 'store_user') {
      const customerIds = await prisma.customer.findMany({
        where: { associatedStoreId: req.user.storeId },
        select: { id: true },
      });
      where.customerId = { in: customerIds.map(c => c.id) };
    }

    const records = await prisma.serviceRecord.findMany({
      where,
      orderBy: { serviceDate: 'desc' },
      include: {
        customer: { select: { id: true, name: true, phone: true } },
        operator: { select: { id: true, name: true } },
      },
    });

    res.json(records);
  } catch (error) {
    console.error('List service records error:', error);
    res.status(500).json({ error: '获取服务记录失败' });
  }
});

// GET /api/service-records/:id - Get detail
router.get('/:id', async (req, res) => {
  try {
    const { id } = req.params;

    const record = await prisma.serviceRecord.findUnique({
      where: { id },
      include: {
        customer: { select: { id: true, name: true, phone: true } },
        operator: { select: { id: true, name: true } },
        transaction: { select: { id: true, status: true } },
      },
    });

    if (!record) {
      return res.status(404).json({ error: '记录不存在' });
    }

    // Permission check
    if (req.user.role === 'store_user') {
      const customer = await prisma.customer.findUnique({
        where: { id: record.customerId },
        select: { associatedStoreId: true },
      });
      if (customer?.associatedStoreId !== req.user.storeId) {
        return res.status(403).json({ error: '无权访问' });
      }
    }

    res.json(record);
  } catch (error) {
    console.error('Get service record error:', error);
    res.status(500).json({ error: '获取服务记录失败' });
  }
});

// POST /api/service-records - Create service record
router.post('/', async (req, res) => {
  try {
    const data = snakeToCamelKeys(req.body);
    console.log("[DEBUG] POST service-records converted data keys:", Object.keys(data));

    const customer = await prisma.customer.findUnique({
      where: { id: data.customerId },
      select: { id: true, associatedStoreId: true, remainingSessions: true },
    });
    if (!customer) return res.status(404).json({ error: '客户不存在' });
    if (req.user.role === 'store_user' && customer.associatedStoreId !== req.user.storeId) {
      return res.status(403).json({ error: '无权为该客户添加服务记录' });
    }

    let serviceBranch = data.branch || '光电';

    const record = await prisma.$transaction(async (tx) => {
      let extraTxId = null;

      if (data.transactionId) {
        const transaction = await tx.transaction.findUnique({
          where: { id: data.transactionId },
          select: { id: true, totalSessions: true, completedSessions: true, branch: true },
        });
        if (transaction) {
          if (!data.branch && transaction.branch) serviceBranch = transaction.branch;
          await tx.transaction.update({
            where: { id: data.transactionId },
            data: {
              completedSessions: Math.min(transaction.totalSessions, transaction.completedSessions + (data.sessionsUsed || 0)),
            },
          });
        }
      }

      const txCount = await tx.transaction.count({ where: { customerId: data.customerId } });
      let newRemaining;
      if (txCount > 0) {
        const txs = await tx.transaction.findMany({
          where: { customerId: data.customerId },
          select: { totalSessions: true, completedSessions: true },
        });
        newRemaining = txs.reduce((sum, t) => sum + (t.totalSessions - t.completedSessions), 0);
      } else {
        newRemaining = (customer.remainingSessions || 0) - (data.sessionsUsed || 0);
      }

      const newRecord = await tx.serviceRecord.create({
        data: {
          ...data,
          operatorId: req.user.userId,
          operatorName: data.operatorName || req.user.name,
          branch: serviceBranch,
          remainingSessions: newRemaining >= 0 ? newRemaining : 0,
        },
        include: {
          customer: { select: { id: true, name: true } },
          operator: { select: { id: true, name: true } },
        },
      });

      await tx.customer.update({
        where: { id: data.customerId },
        data: {
          remainingSessions: newRemaining >= 0 ? newRemaining : 0,
          lastVisit: new Date(),
        },
      });

      if (data.extraPayment > 0) {
        const customPackageId = await getOrCreateCustomPackage();
        const extraPaymentTx = await tx.transaction.create({
          data: {
            customerId: data.customerId,
            storeId: customer.associatedStoreId,
            packageId: customPackageId,
            staffUserId: req.user.userId,
            createdByName: req.user.name,
            amount: data.extraPayment,
            amountReceived: data.extraPayment,
            outstandingAmount: 0,
            storeRebateAmount: data.rebateAmount || 0,
            totalSessions: 0,
            transactionDate: data.serviceDate ? new Date(data.serviceDate) : new Date(),
            status: 'paid',
            notes: data.extraPaymentNote || '服务记录新增付款',
          },
        });
        extraTxId = extraPaymentTx.id;
        await tx.customer.update({
          where: { id: data.customerId },
          data: {
            amountReceived: { increment: data.extraPayment },
            firstTransactionAmount: { increment: data.extraPayment },
          },
        });
      }

      return { ...newRecord, extraTxId };
    });

    res.status(201).json(record);
  } catch (error) {
    console.error('Create service record error:', error);
    res.status(500).json({ error: '创建服务记录失败' });
  }
});

// PUT /api/service-records/:id
router.put('/:id', async (req, res) => {
  try {
    const { id } = req.params;
    const data = snakeToCamelKeys(req.body);

    const existing = await prisma.serviceRecord.findUnique({
      where: { id },
      include: { customer: { select: { id: true, associatedStoreId: true, remainingSessions: true } } },
    });

    if (!existing) {
      return res.status(404).json({ error: '记录不存在' });
    }

    if (req.user.role === 'store_user' && existing.customer.associatedStoreId !== req.user.storeId) {
      return res.status(403).json({ error: '无权修改' });
    }

    const oldTxId = existing.transactionId;
    const oldSessions = existing.sessionsUsed || 0;
    const newTxId = data.transactionId === undefined ? oldTxId : data.transactionId;
    const newSessions = data.sessionsUsed === undefined ? oldSessions : (data.sessionsUsed || 0);

    // Only adjust completedSessions if transaction or sessions actually changed
    if (oldTxId !== newTxId || oldSessions !== newSessions) {
      // Restore old transaction completed sessions
      if (oldTxId) {
        const tx = await prisma.transaction.findUnique({
          where: { id: oldTxId },
          select: { totalSessions: true, completedSessions: true },
        });
        if (tx) {
          await prisma.transaction.update({
            where: { id: oldTxId },
            data: { completedSessions: Math.max(0, tx.completedSessions - oldSessions) },
          });
        }
      }

      // Apply new transaction completed sessions
      if (newTxId) {
        const tx = await prisma.transaction.findUnique({
          where: { id: newTxId },
          select: { totalSessions: true, completedSessions: true },
        });
        if (tx) {
          await prisma.transaction.update({
            where: { id: newTxId },
            data: { completedSessions: Math.min(tx.totalSessions, Math.max(0, tx.completedSessions + newSessions)) },
          });
        }
      }
    }

    // Recompute customer remaining sessions from transactions
    const txCount = await prisma.transaction.count({ where: { customerId: existing.customer.id } });
    let newRemaining;
    if (txCount > 0) {
      const txs = await prisma.transaction.findMany({
        where: { customerId: existing.customer.id },
        select: { totalSessions: true, completedSessions: true },
      });
      newRemaining = txs.reduce((sum, t) => sum + (t.totalSessions - t.completedSessions), 0);
    } else {
      const customer = await prisma.customer.findUnique({ where: { id: existing.customer.id }, select: { remainingSessions: true } });
      newRemaining = (customer?.remainingSessions || 0) - oldSessions + newSessions;
    }

    const updateData = { ...data };
    delete updateData.customerId;
    delete updateData.createdAt;
    const newTxIdForUpdate = updateData.transactionId;
    delete updateData.transactionId;

    // Treat empty strings from iOS as null for optional string fields
    const optionalStringFields = ['operatorName', 'operatorPhone', 'bodyPart', 'serviceDetails', 'customerFeedback', 'extraPaymentNote'];
    for (const field of optionalStringFields) {
      if (updateData[field] === '') {
        updateData[field] = null;
      }
    }

    const prismaUpdateData = {
      ...updateData,
      remainingSessions: newRemaining >= 0 ? newRemaining : 0,
      
    };
    if (newTxIdForUpdate !== undefined) {
      if (newTxIdForUpdate === null) {
        prismaUpdateData.transaction = { disconnect: true };
      } else {
        prismaUpdateData.transaction = { connect: { id: newTxIdForUpdate } };
      }
    }

    const record = await prisma.serviceRecord.update({
      where: { id },
      data: prismaUpdateData,
      include: {
        customer: { select: { id: true, name: true } },
        operator: { select: { id: true, name: true } },
      },
    });

    await prisma.customer.update({
      where: { id: existing.customer.id },
      data: {
        remainingSessions: newRemaining >= 0 ? newRemaining : 0,
        lastVisit: new Date(),
      },
    });

    // Record any change in extra payment as a transaction (delta)
    const oldExtraPayment = existing.extraPayment || 0;
    const newExtraPayment = data.extraPayment === undefined ? oldExtraPayment : (data.extraPayment || 0);
    const extraDelta = newExtraPayment - oldExtraPayment;
    if (extraDelta !== 0) {
      try {
        const customPackageId = await getOrCreateCustomPackage();
        await prisma.transaction.create({
          data: {
            customerId: existing.customer.id,
            storeId: existing.customer.associatedStoreId,
            packageId: customPackageId,
            staffUserId: req.user.userId,
            createdByName: req.user.name,
            amount: extraDelta,
            amountReceived: extraDelta,
            outstandingAmount: 0,
            storeRebateAmount: data.rebateAmount || 0,
            totalSessions: 0,
            transactionDate: data.serviceDate ? new Date(data.serviceDate) : new Date(),
            status: extraDelta > 0 ? 'paid' : 'refunded',
            notes: data.extraPaymentNote || (extraDelta > 0 ? '服务记录追加付款' : '服务记录退款调整'),
          },
        });
        await prisma.customer.update({
          where: { id: existing.customer.id },
          data: {
            amountReceived: { increment: extraDelta },
            firstTransactionAmount: { increment: extraDelta },
          },
        });
      } catch (paymentErr) {
        console.error('Record extra payment delta transaction error:', paymentErr);
      }
    }

    res.json(record);
  } catch (error) {
    console.error('Update service record error:', error);
    res.status(500).json({ error: '更新失败' });
  }
});

// DELETE /api/service-records/:id
router.delete('/:id', async (req, res) => {
  try {
    const { id } = req.params;

    const existing = await prisma.serviceRecord.findUnique({
      where: { id },
      include: {
        customer: {
          select: { id: true, associatedStoreId: true, remainingSessions: true }
        }
      },
    });

    if (!existing) {
      return res.status(404).json({ error: '记录不存在' });
    }

    if (req.user.role === 'store_user') {
      return res.status(403).json({ error: '无权删除，请提交删除申请' });
    }

    // Restore linked transaction completed sessions
    if (existing.transactionId) {
      const tx = await prisma.transaction.findUnique({
        where: { id: existing.transactionId },
        select: { totalSessions: true, completedSessions: true },
      });
      if (tx) {
        await prisma.transaction.update({
          where: { id: existing.transactionId },
          data: {
            completedSessions: Math.max(0, tx.completedSessions - existing.sessionsUsed),
          },
        });
      }
    }

    // Recompute customer remaining sessions
    const txCount = await prisma.transaction.count({ where: { customerId: existing.customer.id } });
    let restoredRemaining;
    if (txCount > 0) {
      const txs = await prisma.transaction.findMany({
        where: { customerId: existing.customer.id },
        select: { totalSessions: true, completedSessions: true },
      });
      restoredRemaining = txs.reduce((sum, t) => sum + (t.totalSessions - t.completedSessions), 0);
    } else {
      restoredRemaining = (existing.customer.remainingSessions || 0) + existing.sessionsUsed;
    }

    await prisma.customer.update({
      where: { id: existing.customer.id },
      data: { remainingSessions: restoredRemaining >= 0 ? restoredRemaining : 0 },
    });

    await prisma.serviceRecord.delete({ where: { id } });
    res.json({ success: true });
  } catch (error) {
    console.error('Delete service record error:', error);
    res.status(500).json({ error: '删除失败' });
  }
});


async function applyServiceRecordUpdate(id, rawData, userId, userName) {
  const data = snakeToCamelKeys(rawData);

  const existing = await prisma.serviceRecord.findUnique({
    where: { id },
    include: { customer: { select: { id: true, associatedStoreId: true, remainingSessions: true } } },
  });

  if (!existing) {
    throw new Error('记录不存在');
  }

  const oldTxId = existing.transactionId;
  const oldSessions = existing.sessionsUsed || 0;
  const newTxId = data.transactionId === undefined ? oldTxId : data.transactionId;
  const newSessions = data.sessionsUsed === undefined ? oldSessions : (data.sessionsUsed || 0);

  if (oldTxId !== newTxId || oldSessions !== newSessions) {
    if (oldTxId) {
      const tx = await prisma.transaction.findUnique({
        where: { id: oldTxId },
        select: { totalSessions: true, completedSessions: true },
      });
      if (tx) {
        await prisma.transaction.update({
          where: { id: oldTxId },
          data: { completedSessions: Math.max(0, tx.completedSessions - oldSessions) },
        });
      }
    }

    if (newTxId) {
      const tx = await prisma.transaction.findUnique({
        where: { id: newTxId },
        select: { totalSessions: true, completedSessions: true },
      });
      if (tx) {
        await prisma.transaction.update({
          where: { id: newTxId },
          data: { completedSessions: Math.min(tx.totalSessions, Math.max(0, tx.completedSessions + newSessions)) },
        });
      }
    }
  }

  const txCount = await prisma.transaction.count({ where: { customerId: existing.customer.id } });
  let newRemaining;
  if (txCount > 0) {
    const txs = await prisma.transaction.findMany({
      where: { customerId: existing.customer.id },
      select: { totalSessions: true, completedSessions: true },
    });
    newRemaining = txs.reduce((sum, t) => sum + (t.totalSessions - t.completedSessions), 0);
  } else {
    const customer = await prisma.customer.findUnique({ where: { id: existing.customer.id }, select: { remainingSessions: true } });
    newRemaining = (customer?.remainingSessions || 0) - oldSessions + newSessions;
  }

  const updateData = { ...data };
  delete updateData.customerId;
  delete updateData.createdAt;
  const newTxIdForUpdate = updateData.transactionId;
  delete updateData.transactionId;

  const optionalStringFields = ['operatorName', 'operatorPhone', 'bodyPart', 'serviceDetails', 'customerFeedback', 'extraPaymentNote'];
  for (const field of optionalStringFields) {
    if (updateData[field] === '') {
      updateData[field] = null;
    }
  }

  const prismaUpdateData = {
    ...updateData,
    remainingSessions: newRemaining >= 0 ? newRemaining : 0,
  };
  if (newTxIdForUpdate !== undefined) {
    if (newTxIdForUpdate === null) {
      prismaUpdateData.transaction = { disconnect: true };
    } else {
      prismaUpdateData.transaction = { connect: { id: newTxIdForUpdate } };
    }
  }

  const record = await prisma.serviceRecord.update({
    where: { id },
    data: prismaUpdateData,
    include: {
      customer: { select: { id: true, name: true } },
      operator: { select: { id: true, name: true } },
    },
  });

  await prisma.customer.update({
    where: { id: existing.customer.id },
    data: {
      remainingSessions: newRemaining >= 0 ? newRemaining : 0,
      lastVisit: new Date(),
    },
  });

  const oldExtraPayment = existing.extraPayment || 0;
  const newExtraPayment = data.extraPayment === undefined ? oldExtraPayment : (data.extraPayment || 0);
  const extraDelta = newExtraPayment - oldExtraPayment;
  if (extraDelta !== 0) {
    try {
      const customPackageId = await getOrCreateCustomPackage();
      await prisma.transaction.create({
        data: {
          customerId: existing.customer.id,
          storeId: existing.customer.associatedStoreId,
          packageId: customPackageId,
          staffUserId: userId,
          createdByName: userName,
          amount: extraDelta,
          amountReceived: extraDelta,
          outstandingAmount: 0,
          storeRebateAmount: data.rebateAmount || 0,
          totalSessions: 0,
          transactionDate: data.serviceDate ? new Date(data.serviceDate) : new Date(),
          status: extraDelta > 0 ? 'paid' : 'refunded',
          notes: data.extraPaymentNote || (extraDelta > 0 ? '服务记录追加付款' : '服务记录退款调整'),
        },
      });
      await prisma.customer.update({
        where: { id: existing.customer.id },
        data: {
          amountReceived: { increment: extraDelta },
          firstTransactionAmount: { increment: extraDelta },
        },
      });
    } catch (paymentErr) {
      console.error('Record extra payment delta transaction error:', paymentErr);
    }
  }

  return record;
}

async function applyServiceRecordDelete(id, userId, userName) {
  const existing = await prisma.serviceRecord.findUnique({
    where: { id },
    include: {
      customer: {
        select: { id: true, associatedStoreId: true, remainingSessions: true }
      }
    },
  });

  if (!existing) {
    throw new Error('记录不存在');
  }

  if (existing.transactionId) {
    const tx = await prisma.transaction.findUnique({
      where: { id: existing.transactionId },
      select: { totalSessions: true, completedSessions: true },
    });
    if (tx) {
      await prisma.transaction.update({
        where: { id: existing.transactionId },
        data: {
          completedSessions: Math.max(0, tx.completedSessions - existing.sessionsUsed),
        },
      });
    }
  }

  const txCount = await prisma.transaction.count({ where: { customerId: existing.customer.id } });
  let restoredRemaining;
  if (txCount > 0) {
    const txs = await prisma.transaction.findMany({
      where: { customerId: existing.customer.id },
      select: { totalSessions: true, completedSessions: true },
    });
    restoredRemaining = txs.reduce((sum, t) => sum + (t.totalSessions - t.completedSessions), 0);
  } else {
    restoredRemaining = (existing.customer.remainingSessions || 0) + existing.sessionsUsed;
  }

  await prisma.customer.update({
    where: { id: existing.customer.id },
    data: { remainingSessions: restoredRemaining >= 0 ? restoredRemaining : 0 },
  });

  await prisma.serviceRecord.delete({ where: { id } });
  return { success: true };
}

module.exports.applyServiceRecordUpdate = applyServiceRecordUpdate;
module.exports.applyServiceRecordDelete = applyServiceRecordDelete;

module.exports = router;
