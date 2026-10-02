const express = require('express');
const prisma = require('../config/database');
const { authMiddleware, requireSuperAdmin } = require('../middleware/auth');
const transactionHelpers = require('../routes/transactions');
const serviceRecordHelpers = require('../routes/serviceRecords');

const router = express.Router();
router.use(authMiddleware);

// POST /api/operation-approvals - Submit a new approval request
router.post('/', async (req, res) => {
  try {
    const { operationType, targetType, targetId, payload } = req.body;

    if (!operationType || !targetType || !targetId) {
      return res.status(400).json({ error: '缺少必要参数' });
    }

    if (!['update', 'delete'].includes(operationType) || !['transaction', 'service_record', 'customer', 'store', 'package'].includes(targetType)) {
      return res.status(400).json({ error: '无效的操作类型或目标类型' });
    }

    const approval = await prisma.operationApproval.create({
      data: {
        operationType,
        targetType,
        targetId,
        payload: payload || {},
        requestedBy: req.user.userId,
        requestedByName: req.user.name || '',
        status: 'pending',
      },
    });

    res.status(201).json({ success: true, approval });
  } catch (error) {
    console.error('Create operation approval error:', error);
    res.status(500).json({ error: '提交审批申请失败' });
  }
});

// GET /api/operation-approvals - super_admin only, list all approvals
router.get('/', requireSuperAdmin, async (req, res) => {
  try {
    const approvals = await prisma.operationApproval.findMany({
      orderBy: { createdAt: 'desc' },
    });
    res.json({ success: true, approvals });
  } catch (error) {
    console.error('List all approvals error:', error);
    res.status(500).json({ error: '获取审批记录失败' });
  }
});

// GET /api/operation-approvals/pending - super_admin only
router.get('/pending', requireSuperAdmin, async (req, res) => {
  try {
    const approvals = await prisma.operationApproval.findMany({
      where: { status: 'pending' },
      orderBy: { createdAt: 'desc' },
    });
    res.json({ success: true, approvals });
  } catch (error) {
    console.error('List pending approvals error:', error);
    res.status(500).json({ error: '获取待审批列表失败' });
  }
});

// GET /api/operation-approvals/mine - current user's submitted approvals
router.get('/mine', async (req, res) => {
  try {
    const approvals = await prisma.operationApproval.findMany({
      where: { requestedBy: req.user.userId },
      orderBy: { createdAt: 'desc' },
    });
    res.json({ success: true, approvals });
  } catch (error) {
    console.error('List my approvals error:', error);
    res.status(500).json({ error: '获取我的审批记录失败' });
  }
});

// POST /api/operation-approvals/:id/approve - super_admin executes the operation
router.post('/:id/approve', requireSuperAdmin, async (req, res) => {
  try {
    const { id } = req.params;
    const approval = await prisma.operationApproval.findUnique({ where: { id } });

    if (!approval) {
      return res.status(404).json({ error: '审批记录不存在' });
    }
    if (approval.status !== 'pending') {
      return res.status(409).json({ error: '该审批不是待处理状态' });
    }

    let result;
    if (approval.targetType === 'transaction') {
      if (approval.operationType === 'update') {
        result = await transactionHelpers.applyTransactionUpdate(approval.targetId, approval.payload, req.user.userId, req.user.name || '');
      } else if (approval.operationType === 'delete') {
        result = await transactionHelpers.applyTransactionDelete(approval.targetId, req.user.userId, req.user.name || '');
      } else {
        return res.status(400).json({ error: '无效的操作类型' });
      }
    } else if (approval.targetType === 'service_record') {
      if (approval.operationType === 'update') {
        result = await serviceRecordHelpers.applyServiceRecordUpdate(approval.targetId, approval.payload, req.user.userId, req.user.name || '');
      } else if (approval.operationType === 'delete') {
        result = await serviceRecordHelpers.applyServiceRecordDelete(approval.targetId, req.user.userId, req.user.name || '');
      } else {
        return res.status(400).json({ error: '无效的操作类型' });
      }
    } else if (approval.targetType === 'customer') {
      if (approval.operationType === 'delete') {
        const customer = await prisma.customer.findUnique({
          where: { id: approval.targetId },
          select: { remainingSessions: true },
        });
        if (!customer) {
          return res.status(404).json({ error: '客户不存在' });
        }
        if (customer.remainingSessions > 0) {
          return res.status(400).json({
            error: `该客户还有 ${customer.remainingSessions} 次待交付服务，请确认已交付完成后再删除`,
            remainingSessions: customer.remainingSessions,
          });
        }
        await prisma.customer.delete({ where: { id: approval.targetId } });
        result = { success: true, deletedCustomerId: approval.targetId };
      } else {
        return res.status(400).json({ error: '无效的操作类型' });
      }
    } else if (approval.targetType === 'store') {
      if (approval.operationType === 'delete') {
        const store = await prisma.store.findUnique({
          where: { id: approval.targetId },
          select: { id: true },
        });
        if (!store) {
          return res.status(404).json({ error: '门店不存在' });
        }
        const customerCount = await prisma.customer.count({
          where: { associatedStoreId: approval.targetId },
        });
        if (customerCount > 0) {
          return res.status(400).json({
            error: `该门店下还有 ${customerCount} 位客户，请先转移或删除客户`,
            customerCount,
          });
        }
        await prisma.store.delete({ where: { id: approval.targetId } });
        result = { success: true, deletedStoreId: approval.targetId };
      } else {
        return res.status(400).json({ error: '无效的操作类型' });
      }
    } else if (approval.targetType === 'package') {
      if (approval.operationType === 'delete') {
        const pkg = await prisma.servicePackage.findUnique({
          where: { id: approval.targetId },
          select: { id: true },
        });
        if (!pkg) {
          return res.status(404).json({ error: '套餐不存在' });
        }
        const txnCount = await prisma.transaction.count({
          where: { packageId: approval.targetId },
        });
        if (txnCount > 0) {
          return res.status(400).json({
            error: `该套餐已被 ${txnCount} 笔成交引用，无法删除`,
            transactionCount: txnCount,
          });
        }
        await prisma.servicePackage.delete({ where: { id: approval.targetId } });
        result = { success: true, deletedPackageId: approval.targetId };
      } else {
        return res.status(400).json({ error: '无效的操作类型' });
      }
    } else {
      return res.status(400).json({ error: '无效的目标类型' });
    }

    const updated = await prisma.operationApproval.update({
      where: { id },
      data: {
        status: 'approved',
        reviewedBy: req.user.userId,
        reviewedByName: req.user.name || '',
        reviewedAt: new Date(),
      },
    });

    res.json({ success: true, result, approval: updated });
  } catch (error) {
    console.error('Approve operation error:', error);
    res.status(500).json({ error: error.message || '审批通过失败' });
  }
});

// POST /api/operation-approvals/:id/reject - super_admin rejects the request
router.post('/:id/reject', requireSuperAdmin, async (req, res) => {
  try {
    const { id } = req.params;
    const approval = await prisma.operationApproval.findUnique({ where: { id } });

    if (!approval) {
      return res.status(404).json({ error: '审批记录不存在' });
    }
    if (approval.status !== 'pending') {
      return res.status(409).json({ error: '该审批不是待处理状态' });
    }

    const updated = await prisma.operationApproval.update({
      where: { id },
      data: {
        status: 'rejected',
        reviewedBy: req.user.userId,
        reviewedByName: req.user.name || '',
        reviewedAt: new Date(),
      },
    });

    res.json({ success: true, approval: updated });
  } catch (error) {
    console.error('Reject operation error:', error);
    res.status(500).json({ error: '审批拒绝失败' });
  }
});

module.exports = router;
