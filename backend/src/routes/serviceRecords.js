const express = require('express');
const prisma = require('../config/database');
const { authMiddleware } = require('../middleware/auth');

const router = express.Router();
router.use(authMiddleware);

// GET /api/service-records - List service records
router.get('/', async (req, res) => {
  try {
    const { customerId } = req.query;
    const where = {};
    if (customerId) where.customerId = customerId;

    // Join through customer for permission check
    if (req.user.role !== 'admin') {
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
    if (req.user.role !== 'admin') {
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
    const data = req.body;

    // Permission check on customer
    const customer = await prisma.customer.findUnique({
      where: { id: data.customerId },
      select: { associatedStoreId: true, remainingSessions: true },
    });

    if (!customer) {
      return res.status(404).json({ error: '客户不存在' });
    }

    if (req.user.role !== 'admin' && customer.associatedStoreId !== req.user.storeId) {
      return res.status(403).json({ error: '无权为该客户添加服务记录' });
    }

    // Calculate remaining sessions
    let newRemaining = customer.remainingSessions || 0;
    if (data.sessionsUsed) {
      newRemaining -= data.sessionsUsed;
    }
    if (data.extraPayment && data.extraPayment > 0) {
      // Assume 1 session per extra payment unit, or adjust as needed
      // This is a simplification - actual logic depends on business rules
    }

    const record = await prisma.serviceRecord.create({
      data: {
        ...data,
        operatorId: req.user.userId,
        remainingSessions: newRemaining >= 0 ? newRemaining : 0,
      },
      include: {
        customer: { select: { id: true, name: true } },
        operator: { select: { id: true, name: true } },
      },
    });

    // Update customer remaining sessions and last visit
    await prisma.customer.update({
      where: { id: data.customerId },
      data: { 
        remainingSessions: newRemaining >= 0 ? newRemaining : 0,
        lastVisit: new Date(),
      },
    });
    await prisma.customer.update({
      where: { id: data.customerId },
      data: { remainingSessions: newRemaining >= 0 ? newRemaining : 0 },
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
    const data = req.body;

    const existing = await prisma.serviceRecord.findUnique({
      where: { id },
      include: { customer: { select: { associatedStoreId: true } } },
    });

    if (!existing) {
      return res.status(404).json({ error: '记录不存在' });
    }

    if (req.user.role !== 'admin' && existing.customer.associatedStoreId !== req.user.storeId) {
      return res.status(403).json({ error: '无权修改' });
    }

    const record = await prisma.serviceRecord.update({
      where: { id },
      data: { ...data, updatedAt: new Date() },
    });

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
      include: { customer: { select: { associatedStoreId: true } } },
    });

    if (!existing) {
      return res.status(404).json({ error: '记录不存在' });
    }

    if (req.user.role !== 'admin') {
      return res.status(403).json({ error: '无权删除，请提交删除申请' });
    }

    await prisma.serviceRecord.delete({ where: { id } });
    res.json({ success: true });
  } catch (error) {
    console.error('Delete service record error:', error);
    res.status(500).json({ error: '删除失败' });
  }
});

module.exports = router;
