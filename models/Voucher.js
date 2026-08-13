const prisma = require('../config/prisma');

class Voucher {
  static async listActive() {
    return prisma.voucher.findMany({
      where: { isActive: true },
      orderBy: { code: 'asc' },
    });
  }

  static async getSelectedForCart(cartId) {
    const selection = await prisma.cartVoucher.findUnique({
      where: { cartId },
      include: { voucher: true },
    });
    return selection?.voucher || null;
  }

  static async selectForCart(memberId, cartId, voucherCode) {
    const code = String(voucherCode || '').trim().toUpperCase();
    if (!code) throw new Error('Select a voucher before applying it.');

    const cart = await prisma.cart.findFirst({
      where: { cartId, memberId, status: 'ACTIVE' },
      select: { cartId: true },
    });
    if (!cart) throw new Error('Active cart not found.');

    const voucher = await prisma.voucher.findFirst({
      where: { code, isActive: true },
    });
    if (!voucher) throw new Error('Voucher is unavailable or inactive.');

    await prisma.cartVoucher.upsert({
      where: { cartId },
      create: { cartId, voucherId: voucher.voucherId },
      update: { voucherId: voucher.voucherId },
    });
    return voucher;
  }

  static async clearForCart(memberId, cartId) {
    const cart = await prisma.cart.findFirst({
      where: { cartId, memberId, status: 'ACTIVE' },
      select: { cartId: true },
    });
    if (!cart) throw new Error('Active cart not found.');

    await prisma.cartVoucher.deleteMany({ where: { cartId } });
  }
}

module.exports = Voucher;
