const express = require("express");
const prisma = require("../config/database");
const { authMiddleware } = require("../middleware/auth");

const router = express.Router();
router.use(authMiddleware);

function startOfDay(d) {
  return new Date(d.getFullYear(), d.getMonth(), d.getDate());
}
function startOfMonth(d) {
  return new Date(d.getFullYear(), d.getMonth(), 1);
}
function startOfYear(d) {
  return new Date(d.getFullYear(), 0, 1);
}

router.get("/summary", async (req, res) => {
  try {
    const now = new Date();
    const todayStart = startOfDay(now);
    const monthStart = startOfMonth(now);
    const lastMonthStart = new Date(now.getFullYear(), now.getMonth() - 1, 1);
    const yearStart = startOfYear(now);

    const storeWhere = {};
    if (req.user.role === "store_user" && req.user.storeId) {
      storeWhere.id = req.user.storeId;
    }

    const stores = await prisma.store.findMany({
      where: storeWhere,
      select: { id: true, name: true },
    });
    const storeIds = stores.map((s) => s.id);

    const [
      todayStats,
      monthStats,
      lastMonthStats,
      yearStats,
      pendingStats,
      customerCount,
      topStores,
      topCustomers,
      rebatePeriods,
    ] = await Promise.all([
      prisma.transaction.groupBy({
        by: ["branch"],
        where: {
          storeId: { in: storeIds },
          status: { in: ["paid", "refunded", "confirmed", "inProgress"] },
          transactionDate: { gte: todayStart },
        },
        _sum: { amount: true, amountReceived: true, outstandingAmount: true },
        _count: { id: true },
      }),
      prisma.transaction.groupBy({
        by: ["branch"],
        where: {
          storeId: { in: storeIds },
          status: { in: ["paid", "refunded", "confirmed", "inProgress"] },
          transactionDate: { gte: monthStart },
        },
        _sum: { amount: true, amountReceived: true, outstandingAmount: true },
        _count: { id: true },
      }),
      prisma.transaction.groupBy({
        by: ["branch"],
        where: {
          storeId: { in: storeIds },
          status: { in: ["paid", "refunded", "confirmed", "inProgress"] },
          transactionDate: { gte: lastMonthStart, lt: monthStart },
        },
        _sum: { amount: true, amountReceived: true, outstandingAmount: true },
        _count: { id: true },
      }),
      prisma.transaction.groupBy({
        by: ["branch"],
        where: {
          storeId: { in: storeIds },
          status: { in: ["paid", "refunded", "confirmed", "inProgress"] },
          transactionDate: { gte: yearStart },
        },
        _sum: { amount: true, amountReceived: true, outstandingAmount: true },
        _count: { id: true },
      }),
      prisma.transaction.count({
        where: {
          storeId: { in: storeIds },
          status: { in: ["pending", "confirmed", "inProgress"] },
        },
      }),
      prisma.customer.count({
        where: storeIds.length ? { associatedStoreId: { in: storeIds } } : {},
      }),
      prisma.transaction.groupBy({
        by: ["storeId"],
        where: {
          storeId: { in: storeIds },
          status: { in: ["paid", "refunded", "confirmed", "inProgress"] },
          transactionDate: { gte: monthStart },
        },
        _sum: { amountReceived: true },
        orderBy: { _sum: { amountReceived: "desc" } },
        take: 5,
      }),
      prisma.transaction.groupBy({
        by: ["customerId"],
        where: {
          storeId: { in: storeIds },
          status: { in: ["paid", "refunded", "confirmed", "inProgress"] },
          transactionDate: { gte: monthStart },
        },
        _sum: { amountReceived: true },
        orderBy: { _sum: { amountReceived: "desc" } },
        take: 5,
      }),
      prisma.storeRebatePeriod.findMany({
        where: {
          storeId: { in: storeIds },
          status: "confirmed",
        },
        select: {
          storeId: true,
          confirmedRebate: true,
          confirmedAt: true,
        },
      }),
    ]);

    const sumBranch = (rows, branch) => {
      const r = rows.find((x) => x.branch === branch);
      return {
        amount: r?._sum?.amount || 0,
        received: r?._sum?.amountReceived || 0,
        outstanding: r?._sum?.outstandingAmount || 0,
        count: r?._count?.id || 0,
      };
    };

    const todayPhoto = sumBranch(todayStats, "光电");
    const todayMedical = sumBranch(todayStats, "医美");
    const monthPhoto = sumBranch(monthStats, "光电");
    const monthMedical = sumBranch(monthStats, "医美");
    const lastMonthPhoto = sumBranch(lastMonthStats, "光电");
    const lastMonthMedical = sumBranch(lastMonthStats, "医美");
    const yearPhoto = sumBranch(yearStats, "光电");
    const yearMedical = sumBranch(yearStats, "医美");

    const todayRebate = rebatePeriods
      .filter((p) => p.confirmedAt && p.confirmedAt >= todayStart)
      .reduce((s, p) => s + (p.confirmedRebate || 0), 0);
    const monthRebate = rebatePeriods
      .filter((p) => p.confirmedAt && p.confirmedAt >= monthStart)
      .reduce((s, p) => s + (p.confirmedRebate || 0), 0);
    const lastMonthRebate = rebatePeriods
      .filter(
        (p) =>
          p.confirmedAt && p.confirmedAt >= lastMonthStart && p.confirmedAt < monthStart
      )
      .reduce((s, p) => s + (p.confirmedRebate || 0), 0);
    const yearRebate = rebatePeriods
      .filter((p) => p.confirmedAt && p.confirmedAt >= yearStart)
      .reduce((s, p) => s + (p.confirmedRebate || 0), 0);

    const topStoreData = await Promise.all(
      topStores.map(async (t) => {
        const store = stores.find((s) => s.id === t.storeId);
        return {
          storeId: t.storeId,
          name: store?.name || "未知门店",
          amount: t._sum.amountReceived || 0,
        };
      })
    );

    const customerIds = topCustomers.map((t) => t.customerId);
    const customerMap = await prisma.customer.findMany({
      where: { id: { in: customerIds } },
      select: { id: true, name: true },
    });
    const topCustomerData = topCustomers.map((t) => ({
      customerId: t.customerId,
      name: customerMap.find((c) => c.id === t.customerId)?.name || "未知客户",
      amount: t._sum.amountReceived || 0,
    }));

    res.json({
      today: {
        photoElectric: todayPhoto,
        medicalBeauty: todayMedical,
        rebate: todayRebate,
      },
      month: {
        photoElectric: monthPhoto,
        medicalBeauty: monthMedical,
        rebate: monthRebate,
      },
      lastMonth: {
        photoElectric: lastMonthPhoto,
        medicalBeauty: lastMonthMedical,
        rebate: lastMonthRebate,
      },
      year: {
        photoElectric: yearPhoto,
        medicalBeauty: yearMedical,
        rebate: yearRebate,
      },
      pendingCount: pendingStats,
      customerCount,
      topStores: topStoreData,
      topCustomers: topCustomerData,
    });
  } catch (error) {
    console.error("Dashboard summary error:", error);
    res.status(500).json({ error: "获取Dashboard数据失败" });
  }
});

module.exports = router;
