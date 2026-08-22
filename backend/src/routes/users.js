const express = require('express');
const bcrypt = require('bcryptjs');
const prisma = require('../config/database');
const { authMiddleware, requireAdmin } = require('../middleware/auth');

const router = express.Router();
router.use(authMiddleware);

// GET /api/users - List users (admin only)
router.get('/', requireAdmin, async (req, res) => {
  try {
    const users = await prisma.user.findMany({
      orderBy: { createdAt: 'desc' },
      include: {
        store: { select: { id: true, name: true } },
      },
    });
    res.json(users);
  } catch (error) {
    console.error('List users error:', error);
    res.status(500).json({ error: '获取用户列表失败' });
  }
});

// GET /api/users/:id
router.get('/:id', async (req, res) => {
  try {
    const { id } = req.params;

    // Users can view their own profile; admin can view anyone
    if (req.user.role !== 'admin' && req.user.userId !== id) {
      return res.status(403).json({ error: '无权访问' });
    }

    const user = await prisma.user.findUnique({
      where: { id },
      include: {
        store: { select: { id: true, name: true } },
      },
    });

    if (!user) {
      return res.status(404).json({ error: '用户不存在' });
    }

    res.json(user);
  } catch (error) {
    console.error('Get user error:', error);
    res.status(500).json({ error: '获取用户信息失败' });
  }
});

// POST /api/users - Create user (admin only)
router.post('/', requireAdmin, async (req, res) => {
  try {
    const { phone, name, role, storeId, password } = req.body;

    const hashedPassword = password ? await bcrypt.hash(password, 10) : null;

    const user = await prisma.user.create({
      data: {
        phone,
        name,
        role: role || 'staff',
        storeId,
        password: hashedPassword,
      },
      include: {
        store: { select: { id: true, name: true } },
      },
    });

    res.status(201).json(user);
  } catch (error) {
    console.error('Create user error:', error);
    res.status(500).json({ error: '创建用户失败' });
  }
});

// PUT /api/users/:id - Update user
router.put('/:id', async (req, res) => {
  try {
    const { id } = req.params;
    const data = req.body;

    // Admin can update anyone; others only themselves
    if (req.user.role !== 'admin' && req.user.userId !== id) {
      return res.status(403).json({ error: '无权修改' });
    }

    // Non-admin cannot change role
    if (req.user.role !== 'admin') {
      delete data.role;
    }

    if (data.password) {
      data.password = await bcrypt.hash(data.password, 10);
    }

    const user = await prisma.user.update({
      where: { id },
      data: { ...data, updatedAt: new Date() },
      include: {
        store: { select: { id: true, name: true } },
      },
    });

    res.json(user);
  } catch (error) {
    console.error('Update user error:', error);
    res.status(500).json({ error: '更新用户失败' });
  }
});

// DELETE /api/users/:id (admin only)
router.delete('/:id', requireAdmin, async (req, res) => {
  try {
    const { id } = req.params;
    await prisma.user.delete({ where: { id } });
    res.json({ success: true });
  } catch (error) {
    console.error('Delete user error:', error);
    res.status(500).json({ error: '删除用户失败' });
  }
});

module.exports = router;
