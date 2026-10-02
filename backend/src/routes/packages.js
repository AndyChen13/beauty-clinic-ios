const express = require('express');
const prisma = require('../config/database');

function snakeToCamelKeys(obj) {
  if (obj === null || typeof obj !== 'object') return obj;
  if (Array.isArray(obj)) return obj.map(snakeToCamelKeys);
  return Object.fromEntries(
    Object.entries(obj).map(([k, v]) => [
      k.replace(/_([a-z])/g, (_, c) => c.toUpperCase()),
      v
    ])
  );
}
const { authMiddleware, requireAdmin } = require('../middleware/auth');

const router = express.Router();
router.use(authMiddleware);

// GET /api/packages - List service packages
router.get('/', async (req, res) => {
  try {
    const { category, isActive } = req.query;
    const where = {};
    if (category) where.category = category;
    if (isActive !== undefined) where.isActive = isActive === 'true';

    const packages = await prisma.servicePackage.findMany({
      where,
      orderBy: { createdAt: 'desc' },
      include: {
        trainingMats: { where: { isActive: true } },
      },
    });

    res.json(packages);
  } catch (error) {
    console.error('List packages error:', error);
    res.status(500).json({ error: '获取套餐列表失败' });
  }
});

// GET /api/packages/:id
router.get('/:id', async (req, res) => {
  try {
    const { id } = req.params;
    const pkg = await prisma.servicePackage.findUnique({
      where: { id },
      include: {
        trainingMats: true,
      },
    });

    if (!pkg) {
      return res.status(404).json({ error: '套餐不存在' });
    }

    res.json(pkg);
  } catch (error) {
    console.error('Get package error:', error);
    res.status(500).json({ error: '获取套餐信息失败' });
  }
});

// POST /api/packages - Create package (admin only)
router.post('/', requireAdmin, async (req, res) => {
  try {
    const pkg = await prisma.servicePackage.create({
      data: snakeToCamelKeys(req.body),
    });
    res.status(201).json(pkg);
  } catch (error) {
    console.error('Create package error:', error);
    res.status(500).json({ error: '创建套餐失败' });
  }
});

// PUT /api/packages/:id (admin only)
router.put('/:id', requireAdmin, async (req, res) => {
  try {
    const { id } = req.params;
    const pkg = await prisma.servicePackage.update({
      where: { id },
      data: { ...snakeToCamelKeys(req.body), updatedAt: new Date() },
    });
    res.json(pkg);
  } catch (error) {
    console.error('Update package error:', error);
    res.status(500).json({ error: '更新套餐失败' });
  }
});

// Training materials endpoints
router.post('/:id/materials', requireAdmin, async (req, res) => {
  try {
    const { id } = req.params;
    const material = await prisma.trainingMaterial.create({
      data: {
        ...snakeToCamelKeys(req.body),
        packageId: id,
      },
    });
    res.status(201).json(material);
  } catch (error) {
    console.error('Create material error:', error);
    res.status(500).json({ error: '创建培训材料失败' });
  }
});


// 删除套餐
router.delete('/:id', authMiddleware, requireAdmin, async (req, res) => {
  try {
    const { id } = req.params;
    const transactionCount = await prisma.transaction.count({ where: { packageId: id } });

    if (transactionCount > 0) {
      return res.status(400).json({ error: '该套餐已被客户使用，无法删除' });
    }

    await prisma.servicePackage.delete({ where: { id } });
    res.json({ success: true, message: '套餐已删除' });
  } catch (error) {
    if (error.code === 'P2025') {
      return res.status(404).json({ error: '套餐不存在' });
    }
    console.error('删除套餐失败:', error);
    res.status(500).json({ error: '删除失败' });
  }
});


module.exports = router;
