const express = require('express');
const prisma = require('../config/database');
const { authMiddleware, requireAdmin } = require('../middleware/auth');

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

const router = express.Router();
router.use(authMiddleware);

// GET /api/training-materials
router.get('/', async (req, res) => {
  try {
    const { category, storeId, search } = req.query;
    const where = {};
    if (category) where.category = category;
    if (storeId) where.storeId = storeId;
    if (search) {
      where.title = { contains: search, mode: 'insensitive' };
    }

    const materials = await prisma.trainingMaterial.findMany({
      where,
      orderBy: { createdAt: 'desc' },
      include: { package: { select: { id: true, name: true } } },
    });
    res.json(materials);
  } catch (error) {
    console.error('List training materials error:', error);
    res.status(500).json({ error: '获取培训资料失败' });
  }
});

// GET /api/training-materials/:id
router.get('/:id', async (req, res) => {
  try {
    const material = await prisma.trainingMaterial.findUnique({
      where: { id: req.params.id },
      include: { package: { select: { id: true, name: true } } },
    });
    if (!material) return res.status(404).json({ error: '培训资料不存在' });
    res.json(material);
  } catch (error) {
    console.error('Get training material error:', error);
    res.status(500).json({ error: '获取培训资料失败' });
  }
});

// POST /api/training-materials
router.post('/', requireAdmin, async (req, res) => {
  try {
    const data = snakeToCamelKeys(req.body);
    const material = await prisma.trainingMaterial.create({
      data: {
        ...data,
        uploadedBy: req.user.userId,
        uploadedByName: req.user.name,
      },
    });
    res.status(201).json(material);
  } catch (error) {
    console.error('Create training material error:', error);
    res.status(500).json({ error: '创建培训资料失败' });
  }
});

// PUT /api/training-materials/:id
router.put('/:id', requireAdmin, async (req, res) => {
  try {
    const data = snakeToCamelKeys(req.body);
    const material = await prisma.trainingMaterial.update({
      where: { id: req.params.id },
      data: { ...data, updatedAt: new Date() },
    });
    res.json(material);
  } catch (error) {
    if (error.code === 'P2025') {
      return res.status(404).json({ error: '培训资料不存在' });
    }
    console.error('Update training material error:', error);
    res.status(500).json({ error: '更新培训资料失败' });
  }
});

// DELETE /api/training-materials/:id
router.delete('/:id', requireAdmin, async (req, res) => {
  try {
    await prisma.trainingMaterial.delete({ where: { id: req.params.id } });
    res.json({ success: true, message: '培训资料已删除' });
  } catch (error) {
    if (error.code === 'P2025') {
      return res.status(404).json({ error: '培训资料不存在' });
    }
    console.error('Delete training material error:', error);
    res.status(500).json({ error: '删除培训资料失败' });
  }
});

module.exports = router;
