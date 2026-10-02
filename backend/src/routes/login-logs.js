const express = require('express');
const prisma = require('../config/database');
const { authMiddleware, requireSuperAdmin } = require('../middleware/auth');

const router = express.Router();

// 所有登录记录接口都需要先认证
router.use(authMiddleware);

// GET /api/login-logs - 查询登录记录（仅超级管理员）
router.get('/', requireSuperAdmin, async (req, res) => {
  try {
    const { userId, phone, startDate, endDate, page = '1', limit = '50' } = req.query;
    const pageNum = Math.max(1, parseInt(page, 10) || 1);
    const limitNum = Math.min(100, Math.max(1, parseInt(limit, 10) || 50));
    const skip = (pageNum - 1) * limitNum;

    const where = {};
    if (userId) where.userId = userId;
    if (phone) where.phone = phone;
    if (startDate || endDate) {
      where.loginAt = {};
      if (startDate) where.loginAt.gte = new Date(startDate);
      if (endDate) where.loginAt.lte = new Date(endDate);
    }

    const [logs, total] = await Promise.all([
      prisma.loginLog.findMany({
        where,
        orderBy: { loginAt: 'desc' },
        skip,
        take: limitNum,
      }),
      prisma.loginLog.count({ where }),
    ]);

    res.json({
      logs,
      pagination: {
        page: pageNum,
        limit: limitNum,
        total,
        totalPages: Math.ceil(total / limitNum),
      },
    });
  } catch (error) {
    console.error('Login logs query error:', error);
    res.status(500).json({ error: '查询登录记录失败' });
  }
});

module.exports = router;
