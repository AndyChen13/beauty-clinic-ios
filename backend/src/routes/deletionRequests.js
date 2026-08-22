const express = require('express');
const prisma = require('../config/database');
const { authMiddleware, requireAdmin } = require('../middleware/auth');

const router = express.Router();
router.use(authMiddleware);

// GET /api/deletion-requests - List deletion requests
router.get('/', async (req, res) => {
  try {
    const where = {};
    if (req.user.role !== 'admin') {
      where.requesterId = req.user.userId;
    }

    const requests = await prisma.deletionRequest.findMany({
      where,
      orderBy: { createdAt: 'desc' },
      include: {
        requester: { select: { id: true, name: true } },
        processor: { select: { id: true, name: true } },
      },
    });

    res.json(requests);
  } catch (error) {
    console.error('List deletion requests error:', error);
    res.status(500).json({ error: '获取删除申请失败' });
  }
});

// POST /api/deletion-requests - Create deletion request
router.post('/', async (req, res) => {
  try {
    const { targetType, targetId, targetName, reason } = req.body;

    const request = await prisma.deletionRequest.create({
      data: {
        requesterId: req.user.userId,
        targetType,
        targetId,
        targetName,
        reason,
        status: 'pending',
      },
    });

    res.status(201).json(request);
  } catch (error) {
    console.error('Create deletion request error:', error);
    res.status(500).json({ error: '提交删除申请失败' });
  }
});

// PUT /api/deletion-requests/:id/approve - Approve (admin only)
router.put('/:id/approve', requireAdmin, async (req, res) => {
  try {
    const { id } = req.params;
    const { adminNotes } = req.body;

    const request = await prisma.deletionRequest.update({
      where: { id },
      data: {
        status: 'approved',
        processedBy: req.user.userId,
        processedAt: new Date(),
        adminNotes,
      },
    });

    // Actually perform the deletion based on targetType
    try {
      if (request.targetType === 'customer') {
        await prisma.customer.delete({ where: { id: request.targetId } });
      } else if (request.targetType === 'service_record') {
        await prisma.serviceRecord.delete({ where: { id: request.targetId } });
      } else if (request.targetType === 'store') {
        await prisma.store.delete({ where: { id: request.targetId } });
      }
    } catch (deleteError) {
      console.error('Auto-delete after approval failed:', deleteError);
      // Don't fail the approval, just log it
    }

    res.json(request);
  } catch (error) {
    console.error('Approve request error:', error);
    res.status(500).json({ error: '审批失败' });
  }
});

// PUT /api/deletion-requests/:id/reject - Reject (admin only)
router.put('/:id/reject', requireAdmin, async (req, res) => {
  try {
    const { id } = req.params;
    const { adminNotes } = req.body;

    const request = await prisma.deletionRequest.update({
      where: { id },
      data: {
        status: 'rejected',
        processedBy: req.user.userId,
        processedAt: new Date(),
        adminNotes,
      },
    });

    res.json(request);
  } catch (error) {
    console.error('Reject request error:', error);
    res.status(500).json({ error: '审批失败' });
  }
});

module.exports = router;
