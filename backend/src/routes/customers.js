const express = require('express');
const { body, validationResult } = require('express-validator');
const prisma = require('../config/database');
const { authMiddleware, requireSuperAdmin } = require('../middleware/auth');

const router = express.Router();
router.use(authMiddleware);

// GET /api/customers - List customers
router.get('/', async (req, res) => {
  try {
    const { storeId, search } = req.query;
    const where = {};

    // Permission filter
    if (req.user.role === 'store_user') {
      where.associatedStoreId = req.user.storeId;
    } else if (storeId) {
      where.associatedStoreId = storeId;
    }

    // Search
    if (search) {
      where.OR = [
        { name: { contains: search, mode: 'insensitive' } },
        { phone: { contains: search } },
      ];
    }

    const customers = await prisma.customer.findMany({
      where,
      orderBy: { createdAt: 'desc' },
      include: {
        store: { select: { id: true, name: true } },
        creator: { select: { id: true, name: true } },
        _count: { select: { serviceRecords: true, transactions: true } },
      },
    });

    res.json(customers);
  } catch (error) {
    console.error('List customers error:', error);
    res.status(500).json({ error: '获取客户列表失败' });
  }
});

// GET /api/customers/:id - Get customer detail
router.get('/:id', async (req, res) => {
  try {
    const { id } = req.params;

    const customer = await prisma.customer.findUnique({
      where: { id },
      include: {
        store: { select: { id: true, name: true } },
        creator: { select: { id: true, name: true } },
        photos: true,
        serviceRecords: {
          orderBy: { serviceDate: 'desc' },
          include: { operator: { select: { name: true } } },
        },
        transactions: {
          include: { package: { select: { name: true } }, store: { select: { name: true } } },
        },
      },
    });

    if (!customer) {
      return res.status(404).json({ error: '客户不存在' });
    }

    // Check permission
    if (req.user.role === 'store_user' && customer.associatedStoreId !== req.user.storeId) {
      return res.status(403).json({ error: '无权访问该客户' });
    }

    res.json(customer);
  } catch (error) {
    console.error('Get customer error:', error);
    res.status(500).json({ error: '获取客户信息失败' });
  }
});

// POST /api/customers - Create customer
router.post('/', [
  body('name').trim().notEmpty().withMessage('姓名不能为空'),
], async (req, res) => {
  const errors = validationResult(req);
  if (!errors.isEmpty()) {
    return res.status(400).json({ errors: errors.array() });
  }

  try {
    const data = Object.fromEntries(
    Object.entries(req.body).map(([k, v]) => [
      k.replace(/_([a-z])/g, (_, c) => c.toUpperCase()),
      v
    ])
  );

    // Non-admin must assign to their store
    if (req.user.role === 'store_user' && !data.associatedStoreId) {
      data.associatedStoreId = req.user.storeId;
    }

    const customer = await prisma.customer.create({
      data: {
        ...data,
        createdBy: req.user.userId,
        createdByName: req.user.name,
        preferences: data.preferences || {},
      },
      include: {
        store: { select: { id: true, name: true } },
      },
    });

    res.status(201).json(customer);
  } catch (error) {
    console.error('Create customer error:', error);
    res.status(500).json({ error: '创建客户失败' });
  }
});

// PUT /api/customers/:id - Update customer
router.put('/:id', async (req, res) => {
  try {
    const { id } = req.params;

    // Check permission
    const existing = await prisma.customer.findUnique({
      where: { id },
      select: { associatedStoreId: true, createdBy: true },
    });

    if (!existing) {
      return res.status(404).json({ error: '客户不存在' });
    }

    if (req.user.role === 'store_user' && existing.associatedStoreId !== req.user.storeId) {
      return res.status(403).json({ error: '无权修改该客户' });
    }

    const data = Object.fromEntries(
    Object.entries(req.body).map(([k, v]) => [
      k.replace(/_([a-z])/g, (_, c) => c.toUpperCase()),
      v
    ])
  );
    delete data.id; // Prevent ID modification
    delete data.createdBy; // Prevent creator modification

    // 前端未传头像时保留原头像，避免编辑客户资料把头像清空
    if (data.photoUrl === null || data.photoUrl === undefined) {
      delete data.photoUrl;
    }

    if (data.preferences) {
      data.preferences = data.preferences;
    }

    const customer = await prisma.customer.update({
      where: { id },
      data: { ...data, updatedAt: new Date() },
      include: {
        store: { select: { id: true, name: true } },
      },
    });

    res.json(customer);
  } catch (error) {
    console.error('Update customer error:', error);
    res.status(500).json({ error: '更新客户信息失败' });
  }
});

// DELETE /api/customers/:id - Delete customer
router.delete('/:id', requireSuperAdmin, async (req, res) => {
  try {
    const { id } = req.params;

    const customer = await prisma.customer.findUnique({
      where: { id },
      select: { associatedStoreId: true, remainingSessions: true, name: true },
    });

    if (!customer) {
      return res.status(404).json({ error: '客户不存在' });
    }

    // Super admin can delete, but check remaining sessions
    if (customer.remainingSessions > 0) {
      return res.status(400).json({
        error: `该客户还有 ${customer.remainingSessions} 次待交付服务，请确认已交付完成后再删除`,
        remainingSessions: customer.remainingSessions,
        customerName: customer.name,
      });
    }

    await prisma.customer.delete({ where: { id } });
    res.json({ success: true });
  } catch (error) {
    console.error('Delete customer error:', error);
    res.status(500).json({ error: '删除客户失败' });
  }
});


// GET /api/customers/:id/photos - List customer photos
router.get('/:id/photos', async (req, res) => {
  try {
    const { id } = req.params;
    const customer = await prisma.customer.findUnique({
      where: { id },
      select: { associatedStoreId: true },
    });
    if (req.user.role === 'store_user' && customer.associatedStoreId !== req.user.storeId) {
      return res.status(403).json({ error: '无权查看该客户照片' });
    }
    const photos = await prisma.customerPhoto.findMany({
      where: { customerId: id },
      orderBy: { createdAt: 'desc' },
    });
    res.json(photos);
  } catch (error) {
    console.error('Get customer photos error:', error);
    res.status(500).json({ error: '获取客户照片失败' });
  }
});

// POST /api/customers/:id/photos - Add a customer photo
router.post('/:id/photos', async (req, res) => {
  try {
    const { id } = req.params;
    const body = req.body;
    const data = Object.fromEntries(
      Object.entries(body).map(([k, v]) => [
        k.replace(/_([a-z])/g, (_, c) => c.toUpperCase()),
        v
      ])
    );
    const customer = await prisma.customer.findUnique({
      where: { id },
      select: { associatedStoreId: true },
    });
    if (req.user.role === 'store_user' && customer.associatedStoreId !== req.user.storeId) {
      return res.status(403).json({ error: '无权添加该客户照片' });
    }
    const photo = await prisma.customerPhoto.create({
      data: {
        customerId: id,
        photoUrl: data.photoUrl,
        photoType: data.photoType || 'progress',
        notes: data.notes,
        uploadedBy: data.uploadedBy || req.user.userId,
        uploadedByName: req.user.name,
      },
    });
    res.status(201).json(photo);
  } catch (error) {
    console.error('Create customer photo error:', error);
    res.status(500).json({ error: '添加客户照片失败' });
  }
});

module.exports = router;
