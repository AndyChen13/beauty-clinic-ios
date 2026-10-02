const express = require('express');
const bcrypt = require('bcryptjs');
const { body, validationResult } = require('express-validator');
const prisma = require('../config/database');
const { generateToken, authMiddleware } = require('../middleware/auth');

const router = express.Router();

// POST /api/auth/register - 注册（手机号 + 密码）
router.post('/register', [
  body('phone').notEmpty().withMessage('手机号不能为空'),
  body('password').isLength({ min: 6 }).withMessage('密码至少6位'),
  body('name').trim().notEmpty().withMessage('姓名不能为空'),
], async (req, res) => {
  const errors = validationResult(req);
  if (!errors.isEmpty()) {
    return res.status(400).json({ errors: errors.array() });
  }

  const { phone, password, name } = req.body;

  try {
    // Check if phone already exists
    const existing = await prisma.user.findUnique({ where: { phone } });
    if (existing) {
      return res.status(409).json({ error: '该手机号已注册' });
    }

    const hashedPassword = await bcrypt.hash(password, 10);
    const isSuperAdmin = process.env.SUPER_ADMIN_PHONES?.split(',').map(s => s.trim()).includes(phone);
    const user = await prisma.user.create({
      data: {
        phone,
        name,
        password: hashedPassword,
        role: isSuperAdmin ? 'super_admin' : 'staff',
        status: isSuperAdmin ? 'approved' : 'pending',
      },
    });

    // 新注册用户默认 pending，需 super_admin 审批后才能登录
    res.status(201).json({
      success: true,
      message: '注册成功，请等待超级管理员审批',
      user: {
        id: user.id,
        phone: user.phone,
        name: user.name,
        role: user.role,
        status: user.status,
        storeId: user.storeId,
        avatarUrl: user.avatarUrl,
      },
    });
  } catch (error) {
    console.error('Register error:', error);
    res.status(500).json({ error: '注册失败' });
  }
});

// POST /api/auth/login - 登录（手机号 + 密码）
router.post('/login', [
  body('phone').notEmpty(),
  body('password').isLength({ min: 6 }),
], async (req, res) => {
  const errors = validationResult(req);
  if (!errors.isEmpty()) {
    return res.status(400).json({ errors: errors.array() });
  }

  const { phone, password } = req.body;

  try {
    const user = await prisma.user.findUnique({ where: { phone } });
    if (!user || !user.password) {
      return res.status(401).json({ error: '手机号或密码错误' });
    }

    const valid = await bcrypt.compare(password, user.password);
    if (!valid) {
      return res.status(401).json({ error: '手机号或密码错误' });
    }

    if (user.status !== 'approved') {
      return res.status(403).json({ error: '账号未通过审批，请联系超级管理员', status: user.status });
    }

    await prisma.loginLog.create({
      data: {
        userId: user.id,
        userName: user.name,
        phone: user.phone,
        role: user.role,
        ipAddress: req.ip,
        userAgent: req.headers['user-agent'],
        status: 'success',
        loginType: 'password',
      },
    });
    const token = generateToken(user);
    res.json({
      success: true,
      token,
      user: {
        id: user.id,
        phone: user.phone,
        name: user.name,
        role: user.role,
        status: user.status,
        storeId: user.storeId,
        avatarUrl: user.avatarUrl,
      },
    });
  } catch (error) {
    console.error('Login error:', error);
    res.status(500).json({ error: '登录失败' });
  }
});

// GET /api/auth/me - 获取当前用户信息
router.get('/me', authMiddleware, async (req, res) => {
  try {
    const user = await prisma.user.findUnique({
      where: { id: req.user.userId },
      include: { store: true },
    });

    if (!user) {
      return res.status(404).json({ error: '用户不存在' });
    }

    await prisma.loginLog.create({
      data: {
        userId: user.id,
        userName: user.name,
        phone: user.phone,
        role: user.role,
        ipAddress: req.ip,
        userAgent: req.headers['user-agent'],
        status: 'success',
        loginType: 'auto',
      },
    });

    res.json({
      id: user.id,
      phone: user.phone,
      email: user.email,
      name: user.name,
      role: user.role,
      status: user.status,
      storeId: user.storeId,
      avatarUrl: user.avatarUrl,
    });
  } catch (error) {
    console.error('Get me error:', error);
    res.status(500).json({ error: '获取用户信息失败' });
  }
});

module.exports = router;
