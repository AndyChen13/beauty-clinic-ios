const express = require('express');
const bcrypt = require('bcryptjs');
const { body, validationResult } = require('express-validator');
const prisma = require('../config/database');
const { generateToken, authMiddleware } = require('../middleware/auth');
const { generateCode, sendSmsCode } = require('../utils/sms');

const router = express.Router();

// POST /api/auth/send-code - 发送验证码
router.post('/send-code', [
  body('phone').isMobilePhone('zh-CN').withMessage('请输入有效的手机号'),
], async (req, res) => {
  const errors = validationResult(req);
  if (!errors.isEmpty()) {
    return res.status(400).json({ errors: errors.array() });
  }

  const { phone } = req.body;

  try {
    // Rate limit: max 5 codes per phone per hour
    const oneHourAgo = new Date(Date.now() - 60 * 60 * 1000);
    const recentCodes = await prisma.smsCode.count({
      where: {
        phone,
        createdAt: { gte: oneHourAgo },
      },
    });
    if (recentCodes >= 5) {
      return res.status(429).json({ error: '发送过于频繁，请1小时后再试' });
    }

    const code = generateCode();
    const expiresAt = new Date(Date.now() + 5 * 60 * 1000); // 5 minutes

    // Save code to database
    await prisma.smsCode.create({
      data: { phone, code, expiresAt },
    });

    // Send SMS (skip if in development without credentials)
    if (process.env.TENCENT_SECRET_ID && process.env.SMS_APP_ID) {
      await sendSmsCode(phone, code);
    } else {
      console.log(`[DEV] SMS code for ${phone}: ${code}`);
    }

    res.json({ success: true, message: '验证码已发送' });
  } catch (error) {
    console.error('Send code error:', error);
    res.status(500).json({ error: '发送验证码失败' });
  }
});

// POST /api/auth/verify-code - 验证验证码并登录/注册
router.post('/verify-code', [
  body('phone').isMobilePhone('zh-CN').withMessage('请输入有效的手机号'),
  body('code').isLength({ min: 6, max: 6 }).withMessage('验证码为6位数字'),
  body('name').optional().trim().isLength({ min: 1, max: 50 }),
], async (req, res) => {
  const errors = validationResult(req);
  if (!errors.isEmpty()) {
    return res.status(400).json({ errors: errors.array() });
  }

  const { phone, code, name } = req.body;

  try {
    // Find valid code
    const smsCode = await prisma.smsCode.findFirst({
      where: {
        phone,
        code,
        used: false,
        expiresAt: { gt: new Date() },
      },
      orderBy: { createdAt: 'desc' },
    });

    if (!smsCode) {
      return res.status(400).json({ error: '验证码错误或已过期' });
    }

    // Mark code as used
    await prisma.smsCode.update({
      where: { id: smsCode.id },
      data: { used: true },
    });

    // Find or create user
    let user = await prisma.user.findUnique({ where: { phone } });

    if (!user) {
      // New user registration
      if (!name) {
        return res.status(400).json({ error: '新用户需要提供姓名' });
      }
      user = await prisma.user.create({
        data: {
          phone,
          name,
          role: 'staff', // Default role
        },
      });
    }

    const token = generateToken(user);

    res.json({
      success: true,
      token,
      user: {
        id: user.id,
        phone: user.phone,
        name: user.name,
        role: user.role,
        storeId: user.storeId,
        avatarUrl: user.avatarUrl,
      },
    });
  } catch (error) {
    console.error('Verify code error:', error);
    res.status(500).json({ error: '登录失败' });
  }
});

// POST /api/auth/login-password - 密码登录（admin fallback）
router.post('/login-password', [
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

    const token = generateToken(user);
    res.json({
      success: true,
      token,
      user: {
        id: user.id,
        phone: user.phone,
        name: user.name,
        role: user.role,
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

    res.json({
      id: user.id,
      phone: user.phone,
      email: user.email,
      name: user.name,
      role: user.role,
      storeId: user.storeId,
      avatarUrl: user.avatarUrl,
    });
  } catch (error) {
    console.error('Get me error:', error);
    res.status(500).json({ error: '获取用户信息失败' });
  }
});

module.exports = router;
