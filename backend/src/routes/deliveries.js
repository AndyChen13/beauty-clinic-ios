const express = require('express');
const { body, validationResult } = require('express-validator');
const prisma = require('../config/database');
const { authMiddleware } = require('../middleware/auth');

const router = express.Router();
router.use(authMiddleware);

// GET /api/deliveries - List deliveries
router.get('/', async (req, res) => {
  try {
    const { transactionId } = req.query;
    const where = {};
    if (transactionId) where.transactionId = transactionId;

    const deliveries = await prisma.delivery.findMany({
      where,
      orderBy: { sessionNumber: 'asc' },
      include: {
        transaction: {
          select: {
            customerId: true,
            storeId: true,
            customer: { select: { name: true } },
          },
        },
      },
    });

    // Filter by permission
    const filtered = req.user.role === 'admin'
      ? deliveries
      : deliveries.filter(d => d.transaction?.storeId === req.user.storeId);

    res.json(filtered);
  } catch (error) {
    console.error('List deliveries error:', error);
    res.status(500).json({ error: '获取交付记录失败' });
  }
});

// POST /api/deliveries - Create delivery
router.post('/', async (req, res) => {
  try {
    const data = req.body;

    const transaction = await prisma.transaction.findUnique({
      where: { id: data.transactionId },
      select: { storeId: true, completedSessions: true, totalSessions: true },
    });

    if (!transaction) {
      return res.status(404).json({ error: '交易不存在' });
    }

    if (req.user.role !== 'admin' && transaction.storeId !== req.user.storeId) {
      return res.status(403).json({ error: '无权操作' });
    }

    const delivery = await prisma.delivery.create({
      data: {
        ...data,
      },
    });

    // Update transaction completed sessions
    await prisma.transaction.update({
      where: { id: data.transactionId },
      data: {
        completedSessions: { increment: 1 },
        status: transaction.completedSessions + 1 >= transaction.totalSessions ? 'completed' : 'inProgress',
      },
    });

    res.status(201).json(delivery);
  } catch (error) {
    console.error('Create delivery error:', error);
    res.status(500).json({ error: '创建交付记录失败' });
  }
});

module.exports = router;
