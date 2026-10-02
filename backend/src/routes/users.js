const express = require('express');
const bcrypt = require('bcryptjs');
const prisma = require('../config/database');
const { authMiddleware, requireAdmin, requireSuperAdmin } = require('../middleware/auth');

const router = express.Router();
router.use(authMiddleware);

// GET /api/users - List all users (super_admin or admin)
router.get('/', async (req, res) => {
  try {
    if (req.user.role !== 'super_admin') {
      return res.status(403).json({ error: '无权访问' });
    }
    const users = await prisma.user.findMany({
      orderBy: { createdAt: 'desc' },
      include: { store: { select: { id: true, name: true } } },
    });
    res.json(users);
  } catch (error) {
    console.error('List users error:', error);
    res.status(500).json({ error: '获取用户列表失败' });
  }
});

// POST /api/users - Create user (super_admin only)
router.post('/', requireSuperAdmin, async (req, res) => {
  try {
    const { phone, name, role, storeId, password } = req.body;
    if (!phone || !name) {
      return res.status(400).json({ error: '手机号和姓名不能为空' });
    }
    const validRoles = ['super_admin', 'staff'];
    if (role && !validRoles.includes(role)) {
      return res.status(400).json({ error: '无效的角色' });
    }
    const existing = await prisma.user.findUnique({ where: { phone } });
    if (existing) {
      return res.status(409).json({ error: '该手机号已注册' });
    }
    const hashedPassword = password ? await bcrypt.hash(password, 10) : null;
    const user = await prisma.user.create({
      data: {
        phone,
        name,
        role: role || 'staff',
        storeId: storeId || null,
        password: hashedPassword,
      },
      include: { store: { select: { id: true, name: true } } },
    });
    res.status(201).json(user);
  } catch (error) {
    console.error('Create user error:', error);
    res.status(500).json({ error: '创建用户失败' });
  }
});

// PUT /api/users/:id/role - Change user role (super_admin only)
router.put('/:id/role', requireSuperAdmin, async (req, res) => {
  try {
    const { id } = req.params;
    const { role } = req.body;
    const validRoles = ['super_admin', 'staff'];
    if (!role || !validRoles.includes(role)) {
      return res.status(400).json({ error: '无效的角色' });
    }

    // Prevent self-demoval last super_admin
    if (req.user.userId === id && role !== 'super_admin') {
      const superAdminCount = await prisma.user.count({ where: { role: 'super_admin' } });
      if (superAdminCount <= 1) {
        return res.status(409).json({ error: '无法降级：当前仅剩您一位超级管理员' });
      }
    }

    // Prevent demoting last super_admin
    if (role !== 'super_admin') {
      const targetUser = await prisma.user.findUnique({ where: { id } });
      if (targetUser?.role === 'super_admin') {
        const superAdminCount = await prisma.user.count({ where: { role: 'super_admin' } });
        if (superAdminCount <= 1) {
          return res.status(409).json({ error: '无法降级：该用户是仅剩的超级管理员' });
        }
      }
    }

    const user = await prisma.user.update({
      where: { id },
      data: { role, updatedAt: new Date() },
      include: { store: { select: { id: true, name: true } } },
    });
    res.json(user);
  } catch (error) {
    console.error('Change role error:', error);
    res.status(500).json({ error: '更新角色失败' });
  }
});

// PUT /api/users/:id - Update user info (super_admin only for role changes)
router.put('/:id', async (req, res) => {
  try {
    const { id } = req.params;
    const { name, storeId, password } = req.body;

    if (req.user.role !== 'super_admin' && req.user.userId !== id) {
      return res.status(403).json({ error: '无权修改' });
    }

    const data = {};
    if (name) data.name = name;
    if (storeId !== undefined) data.storeId = storeId || null;
    if (password) data.password = await bcrypt.hash(password, 10);

    const user = await prisma.user.update({
      where: { id },
      data: { ...data, updatedAt: new Date() },
      include: { store: { select: { id: true, name: true } } },
    });
    res.json(user);
  } catch (error) {
    console.error('Update user error:', error);
    res.status(500).json({ error: '更新用户失败' });
  }
});

// DELETE /api/users/:id (super_admin only)
router.delete('/:id', requireSuperAdmin, async (req, res) => {
  try {
    const { id } = req.params;

    if (req.user.userId === id) {
      return res.status(403).json({ error: '不能删除自己' });
    }

    const targetUser = await prisma.user.findUnique({ where: { id } });
    if (!targetUser) {
      return res.status(404).json({ error: '用户不存在' });
    }
    if (targetUser.role === 'super_admin') {
      return res.status(403).json({ error: '不能删除超级管理员' });
    }

    await prisma.user.delete({ where: { id } });
    res.json({ success: true, message: '用户已删除' });
  } catch (error) {
    console.error('Delete user error:', error);
    res.status(500).json({ error: '删除用户失败' });
  }
});

// GET /api/admin/pending-users - 获取待审批的新注册用户（super_admin only）
router.get('/pending', requireSuperAdmin, async (req, res) => {
  try {
    const users = await prisma.user.findMany({
      where: { status: 'pending' },
      orderBy: { createdAt: 'desc' },
      select: {
        id: true,
        phone: true,
        name: true,
        role: true,
        status: true,
        createdAt: true,
        storeId: true,
      },
    });
    res.json({ success: true, users });
  } catch (error) {
    console.error('List pending users error:', error);
    res.status(500).json({ error: '获取待审批用户失败' });
  }
});

// POST /api/admin/pending-users/:id/approve - 通过审批
router.post('/pending/:id/approve', requireSuperAdmin, async (req, res) => {
  try {
    const { id } = req.params;
    const user = await prisma.user.findUnique({ where: { id } });
    if (!user) return res.status(404).json({ error: '用户不存在' });
    if (user.status !== 'pending') return res.status(409).json({ error: '该用户不是待审批状态' });

    const updated = await prisma.user.update({
      where: { id },
      data: { status: 'approved', updatedAt: new Date() },
      include: { store: { select: { id: true, name: true } } },
    });
    res.json({ success: true, user: updated });
  } catch (error) {
    console.error('Approve user error:', error);
    res.status(500).json({ error: '审批通过失败' });
  }
});

// POST /api/admin/pending-users/:id/reject - 拒绝审批
router.post('/pending/:id/reject', requireSuperAdmin, async (req, res) => {
  try {
    const { id } = req.params;
    const user = await prisma.user.findUnique({ where: { id } });
    if (!user) return res.status(404).json({ error: '用户不存在' });
    if (user.status !== 'pending') return res.status(409).json({ error: '该用户不是待审批状态' });

    const updated = await prisma.user.update({
      where: { id },
      data: { status: 'rejected', updatedAt: new Date() },
      include: { store: { select: { id: true, name: true } } },
    });
    res.json({ success: true, user: updated });
  } catch (error) {
    console.error('Reject user error:', error);
    res.status(500).json({ error: '拒绝审批失败' });
  }
});

// GET /api/users/:id - Get single user profile
router.get('/:id', async (req, res) => {
  try {
    const { id } = req.params;
    if (req.user.role !== 'super_admin' && req.user.userId !== id) {
      return res.status(403).json({ error: '无权访问' });
    }
    const user = await prisma.user.findUnique({
      where: { id },
      include: { store: { select: { id: true, name: true } } },
    });
    if (!user) return res.status(404).json({ error: '用户不存在' });
    res.json(user);
  } catch (error) {
    console.error('Get user error:', error);
    res.status(500).json({ error: '获取用户信息失败' });
  }
});

module.exports = router;
