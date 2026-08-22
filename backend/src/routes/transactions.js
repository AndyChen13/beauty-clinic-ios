const express = require('express');
const prisma = require('../config/database');
const { authMiddleware } = require('../middleware/auth');

const router = express.Router();
router.use(authMiddleware);

// GET /api/transactions - List transactions
router.get('/', async (req, res) => {
  try {
    const { storeId, customerId, status } = req.query;
    const where = {};

    if (storeId) where.storeId = storeId;
    if (customerId) where.customerId = customerId;
    if (status) where.status = status;

    if (req.user.role !== 'admin') {
      where.storeId = req.user.storeId;
    }

    const transactions = await prisma.transaction.findMany({
      where,
      orderBy: { transactionDate: 'desc' },
      include: {
        customer: { select: { id: true, name: true, phone: true } },
        store: { select: { id: true, name: true } },
        package: { select: { id: true, name: true } },
        _count: { select: { deliveries: true } },
      },
    });

    res.json(transactions);
  } catch (error) {
    console.error('List transactions error:', error);
    res.status(500).json({ error: '获取交易列表失败' });
  }
});

// GET /api/transactions/:id
router.get('/:id', async (req, res) => {
  try {
    const { id } = req.params;

    const transaction = await prisma.transaction.findUnique({
      where: { id },
      include: {
        customer: true,
        store: { select: { id: true, name: true } },
        package: true,
        deliveries: { orderBy: { sessionNumber: 'asc' } },
        serviceRecords: { orderBy: { serviceDate: 'desc' } },
      },
    });

    if (!transaction) {
      return res.status(404).json({ error: '交易不存在' });
    }

    if (req.user.role !== 'admin' && transaction.storeId !== req.user.storeId) {
      return res.status(403).json({ error: '无权访问' });
    }

    res.json(transaction);
  } catch (error) {
    console.error('Get transaction error:', error);
    res.status(500).json({ error: '获取交易信息失败' });
  }
});

// POST /api/transactions - Create transaction
router.post('/', async (req, res) => {
  try {
    const data = req.body;

    // Permission check
    if (req.user.role !== 'admin' && data.storeId !== req.user.storeId) {
      return res.status(403).json({ error: '无权为该门店创建交易' });
    }

    const transaction = await prisma.transaction.create({
      data: {
        ...data,
        staffUserId: req.user.userId,
      },
      include: {
        customer: { select: { id: true, name: true } },
        store: { select: { id: true, name: true } },
        package: { select: { id: true, name: true } },
      },
    });

    // Update customer remaining sessions
    await prisma.customer.update({
      where: { id: data.customerId },
      data: { remainingSessions: { increment: data.totalSessions } },
    });

    res.status(201).json(transaction);
  } catch (error) {
    console.error('Create transaction error:', error);
    res.status(500).json({ error: '创建交易失败' });
  }
});

// PUT /api/transactions/:id
router.put('/:id', async (req, res) => {
  try {
    const { id } = req.params;
    const data = req.body;

    const existing = await prisma.transaction.findUnique({
      where: { id },
      select: { storeId: true },
    });

    if (!existing) {
      return res.status(404).json({ error: '交易不存在' });
    }

    if (req.user.role !== 'admin' && existing.storeId !== req.user.storeId) {
      return res.status(403).json({ error: '无权修改' });
    }

    const transaction = await prisma.transaction.update({
      where: { id },
      data: { ...data, updatedAt: new Date() },
    });

    res.json(transaction);
  } catch (error) {
    console.error('Update transaction error:', error);
    res.status(500).json({ error: '更新失败' });
  }
});

module.exports = router;
