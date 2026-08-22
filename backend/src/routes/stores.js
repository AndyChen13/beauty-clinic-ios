const express = require('express');
const { body, validationResult } = require('express-validator');
const prisma = require('../config/database');
const { authMiddleware, requireAdmin } = require('../middleware/auth');

const router = express.Router();

// All routes require authentication
router.use(authMiddleware);

// GET /api/stores - List stores
router.get('/', async (req, res) => {
  try {
    const { status } = req.query;
    const where = {};
    if (status) where.status = status;

    // Non-admin users can only see their assigned store
    if (req.user.role !== 'admin') {
      where.id = req.user.storeId;
    }

    const stores = await prisma.store.findMany({
      where,
      orderBy: { createdAt: 'desc' },
      include: {
        users: { select: { id: true, name: true, role: true } },
        _count: { select: { customers: true } },
      },
    });

    res.json(stores);
  } catch (error) {
    console.error('List stores error:', error);
    res.status(500).json({ error: '获取门店列表失败' });
  }
});

// GET /api/stores/:id - Get store detail
router.get('/:id', async (req, res) => {
  try {
    const { id } = req.params;

    // Check permission
    if (req.user.role !== 'admin' && req.user.storeId !== id) {
      return res.status(403).json({ error: '无权访问该门店' });
    }

    const store = await prisma.store.findUnique({
      where: { id },
      include: {
        users: { select: { id: true, name: true, phone: true, role: true } },
        customers: {
          select: { id: true, name: true, phone: true, remainingSessions: true },
        },
      },
    });

    if (!store) {
      return res.status(404).json({ error: '门店不存在' });
    }

    res.json(store);
  } catch (error) {
    console.error('Get store error:', error);
    res.status(500).json({ error: '获取门店信息失败' });
  }
});

// POST /api/stores - Create store (admin only)
router.post('/', requireAdmin, [
  body('name').trim().notEmpty().withMessage('门店名称不能为空'),
  body('status').optional().isIn(['active', 'pending', 'closed']),
], async (req, res) => {
  const errors = validationResult(req);
  if (!errors.isEmpty()) {
    return res.status(400).json({ errors: errors.array() });
  }

  try {
    const { name, address, phone, status, imageUrl } = req.body;

    const store = await prisma.store.create({
      data: {
        name,
        address,
        phone,
        status: status || 'pending',
        imageUrl,
      },
    });

    res.status(201).json(store);
  } catch (error) {
    console.error('Create store error:', error);
    res.status(500).json({ error: '创建门店失败' });
  }
});

// PUT /api/stores/:id - Update store (admin only)
router.put('/:id', requireAdmin, async (req, res) => {
  try {
    const { id } = req.params;
    const { name, address, phone, status, managerId, imageUrl } = req.body;

    const store = await prisma.store.update({
      where: { id },
      data: {
        name,
        address,
        phone,
        status,
        managerId,
        imageUrl,
        updatedAt: new Date(),
      },
    });

    res.json(store);
  } catch (error) {
    console.error('Update store error:', error);
    res.status(500).json({ error: '更新门店失败' });
  }
});

// DELETE /api/stores/:id - Delete store (admin only)
router.delete('/:id', requireAdmin, async (req, res) => {
  try {
    const { id } = req.params;

    // Check if store has customers with remaining sessions
    const customersWithSessions = await prisma.customer.findMany({
      where: {
        associatedStoreId: id,
        remainingSessions: { gt: 0 },
      },
      select: { id: true, name: true },
    });

    if (customersWithSessions.length > 0) {
      return res.status(400).json({
        error: '该门店还存在未交付完成的客户',
        customers: customersWithSessions,
      });
    }

    // Check if store has any customers at all
    const customerCount = await prisma.customer.count({
      where: { associatedStoreId: id },
    });

    if (customerCount > 0) {
      return res.status(400).json({
        error: '该门店还有客户档案，建议将状态改为「已关闭」',
        suggestion: 'closed',
      });
    }

    await prisma.store.delete({ where: { id } });
    res.json({ success: true });
  } catch (error) {
    console.error('Delete store error:', error);
    res.status(500).json({ error: '删除门店失败' });
  }
});

module.exports = router;
