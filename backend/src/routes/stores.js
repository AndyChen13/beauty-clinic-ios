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
    if (req.user.role === 'store_user' && req.user.storeId) {
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
    if (req.user.role === 'store_user' && req.user.storeId !== id) {
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
    const { name, address, phone, status, imageUrl, introduction, recommendedHotel } = req.body;

    const store = await prisma.store.create({
      data: {
        name,
        address,
        phone,
        status: status || 'pending',
        imageUrl,
        introduction,
        recommendedHotel,
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
    const { name, address, phone, status, managerId, imageUrl, introduction, recommendedHotel } = req.body;

    const store = await prisma.store.update({
      where: { id },
      data: {
        name,
        address,
        phone,
        status,
        managerId,
        imageUrl,
        introduction,
        recommendedHotel,
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

// Helper: calculate total amount received in a period and auto rebate
async function computeRebateAmount(storeId, startAt, thresholds) {
  const { threshold1, rebate1, threshold2, rebate2, threshold3, rebate3 } = thresholds;

  const result = await prisma.transaction.aggregate({
    where: {
      storeId,
      status: { in: ['paid', 'refunded'] },
      branch: '光电',
      transactionDate: {
        gte: new Date(startAt),
        lte: new Date(),
      },
    },
    _sum: {
      amountReceived: true,
    },
  });

  const currentAmount = result._sum.amountReceived || 0;

  const autoRebate = currentAmount >= threshold3 ? rebate3
    : currentAmount >= threshold2 ? rebate2
    : currentAmount >= threshold1 ? rebate1
    : 0;

  return { currentAmount, autoRebate };
}

// GET /api/stores/:id/rebate/active - Get active rebate period
router.get('/:id/rebate/active', async (req, res) => {
  try {
    const { id } = req.params;

    if (req.user.role === 'store_user' && req.user.storeId !== id) {
      return res.status(403).json({ error: '无权访问该门店' });
    }

    const period = await prisma.storeRebatePeriod.findFirst({
      where: { storeId: id, status: 'active' },
    });

    if (!period) {
      return res.status(404).json({ error: '当前没有进行中的返利周期' });
    }

    const { currentAmount, autoRebate } = await computeRebateAmount(id, period.startAt, {
      threshold1: period.threshold1,
      rebate1: period.rebate1,
      threshold2: period.threshold2,
      rebate2: period.rebate2,
      threshold3: period.threshold3,
      rebate3: period.rebate3,
    });

    res.json({ ...period, currentAmount, autoRebate });
  } catch (error) {
    console.error('Get active rebate error:', error);
    res.status(500).json({ error: '获取返利周期失败' });
  }
});

// POST /api/stores/:id/rebate - Create rebate period (admin/super_admin only)
router.post('/:id/rebate', async (req, res) => {
  try {
    const { id } = req.params;

    if (req.user.role !== 'super_admin' && req.user.role !== 'admin') {
      return res.status(403).json({ error: '无权操作返利' });
    }

    const startAt = req.body.startAt || req.body.start_at;
    const endAt = req.body.endAt !== undefined ? req.body.endAt : req.body.end_at;
    const threshold1 = parseFloat(req.body.threshold1 !== undefined ? req.body.threshold1 : req.body.threshold_1);
    const rebate1 = parseFloat(req.body.rebate1 !== undefined ? req.body.rebate1 : req.body.rebate_1);
    const threshold2 = parseFloat(req.body.threshold2 !== undefined ? req.body.threshold2 : req.body.threshold_2);
    const rebate2 = parseFloat(req.body.rebate2 !== undefined ? req.body.rebate2 : req.body.rebate_2);
    const threshold3 = parseFloat(req.body.threshold3 !== undefined ? req.body.threshold3 : req.body.threshold_3);
    const rebate3 = parseFloat(req.body.rebate3 !== undefined ? req.body.rebate3 : req.body.rebate_3);

    if (isNaN(threshold1) || isNaN(threshold2) || isNaN(threshold3) || isNaN(rebate1) || isNaN(rebate2) || isNaN(rebate3)) {
      return res.status(400).json({ error: '门限和返利金额必须是有效数字' });
    }

    if (threshold1 >= threshold2 || threshold2 >= threshold3) {
      return res.status(400).json({ error: '门限必须满足 threshold1 < threshold2 < threshold3' });
    }

    if (endAt && new Date(startAt) >= new Date(endAt)) {
      return res.status(400).json({ error: 'startAt 必须早于 endAt' });
    }

    const existingActive = await prisma.storeRebatePeriod.findFirst({
      where: { storeId: id, status: 'active' },
    });

    if (existingActive) {
      return res.status(409).json({ error: '该门店已存在进行中的返利周期' });
    }

    const period = await prisma.storeRebatePeriod.create({
      data: {
        storeId: id,
        startAt: new Date(startAt),
        endAt: endAt ? new Date(endAt) : null,
        threshold1: threshold1,
        rebate1: rebate1,
        threshold2: threshold2,
        rebate2: rebate2,
        threshold3: threshold3,
        rebate3: rebate3,
      },
    });

    res.status(201).json(period);
  } catch (error) {
    console.error('Create rebate period error:', error);
    res.status(500).json({ error: '创建返利周期失败' });
  }
});

// POST /api/stores/:id/rebate/close - Close active rebate period (admin/super_admin only)
router.post('/:id/rebate/close', async (req, res) => {
  try {
    const { id } = req.params;

    if (req.user.role !== 'super_admin' && req.user.role !== 'admin') {
      return res.status(403).json({ error: '无权操作返利' });
    }

    const period = await prisma.storeRebatePeriod.findFirst({
      where: { storeId: id, status: 'active' },
    });

    if (!period) {
      return res.status(404).json({ error: '当前没有进行中的返利周期' });
    }

    const { currentAmount, autoRebate } = await computeRebateAmount(id, period.startAt, {
      threshold1: period.threshold1,
      rebate1: period.rebate1,
      threshold2: period.threshold2,
      rebate2: period.rebate2,
      threshold3: period.threshold3,
      rebate3: period.rebate3,
    });

    const rawManualRebate = req.body.manualRebate !== undefined ? req.body.manualRebate : req.body.manual_rebate;
    const confirmedRebate = (rawManualRebate !== undefined && rawManualRebate !== null && rawManualRebate !== '')
      ? parseFloat(rawManualRebate)
      : autoRebate;

    const operator = await prisma.user.findUnique({
      where: { id: req.user.userId },
      select: { name: true },
    });

    const updated = await prisma.storeRebatePeriod.update({
      where: { id: period.id },
      data: {
        status: 'confirmed',
        endAt: new Date(),
        autoRebate,
        confirmedRebate,
        confirmedAt: new Date(),
        confirmedById: req.user.userId,
        confirmedByName: operator?.name || null,
      },
    });

    res.json(updated);
  } catch (error) {
    console.error('Close rebate period error:', error);
    res.status(500).json({ error: '结算返利周期失败' });
  }
});

// GET /api/stores/:id/rebate/history - List confirmed rebate periods
router.get('/:id/rebate/history', async (req, res) => {
  try {
    const { id } = req.params;

    if (req.user.role === 'store_user' && req.user.storeId !== id) {
      return res.status(403).json({ error: '无权访问该门店' });
    }

    const periods = await prisma.storeRebatePeriod.findMany({
      where: { storeId: id, status: 'confirmed' },
      orderBy: { confirmedAt: 'desc' },
    });

    res.json(periods);
  } catch (error) {
    console.error('List rebate history error:', error);
    res.status(500).json({ error: '获取返利历史失败' });
  }
});

// PUT /api/stores/:id/rebate/history/:rebateId - Update confirmed rebate amount (admin/super_admin only)
router.put('/:id/rebate/history/:rebateId', async (req, res) => {
  try {
    const { id, rebateId } = req.params;

    if (req.user.role !== 'super_admin' && req.user.role !== 'admin') {
      return res.status(403).json({ error: '无权操作返利' });
    }

    const confirmedRebate = req.body.confirmedRebate !== undefined ? req.body.confirmedRebate : req.body.confirmed_rebate;

    const existing = await prisma.storeRebatePeriod.findFirst({
      where: { id: rebateId, storeId: id, status: 'confirmed' },
    });

    if (!existing) {
      return res.status(404).json({ error: '返利周期不存在或未确认' });
    }

    const updated = await prisma.storeRebatePeriod.update({
      where: { id: rebateId },
      data: {
        confirmedRebate: parseFloat(confirmedRebate),
      },
    });

    res.json(updated);
  } catch (error) {
    console.error('Update confirmed rebate error:', error);
    res.status(500).json({ error: '更新返利金额失败' });
  }
});

// DELETE /api/stores/:id/rebate/history/:rebateId - Delete confirmed rebate period (admin/super_admin only)
router.delete('/:id/rebate/history/:rebateId', async (req, res) => {
  try {
    const { id, rebateId } = req.params;

    if (req.user.role !== 'super_admin' && req.user.role !== 'admin') {
      return res.status(403).json({ error: '无权操作返利' });
    }

    const existing = await prisma.storeRebatePeriod.findFirst({
      where: { id: rebateId, storeId: id, status: 'confirmed' },
    });

    if (!existing) {
      return res.status(404).json({ error: '返利周期不存在或未确认' });
    }

    await prisma.storeRebatePeriod.delete({
      where: { id: rebateId },
    });

    res.json({ success: true });
  } catch (error) {
    console.error('Delete confirmed rebate error:', error);
    res.status(500).json({ error: '删除返利周期失败' });
  }
});

module.exports = router;
