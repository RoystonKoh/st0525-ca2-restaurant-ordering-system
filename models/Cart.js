const prisma = require('../config/prisma');

function normaliseCart(cart) {
  const items = cart.items.map((item) => {
    const unitPrice = Number(item.product.price);
    return {
      cart_item_id: item.cartItemId,
      product_id: item.productId,
      quantity: item.quantity,
      product: {
        product_id: item.product.productId,
        name: item.product.name,
        description: item.product.description,
        category: item.product.category,
        is_available: item.product.isAvailable,
        price: unitPrice,
      },
      subtotal: Number((unitPrice * item.quantity).toFixed(2)),
    };
  });

  return {
    cart_id: cart.cartId,
    member_id: cart.memberId,
    status: cart.status,
    created_at: cart.createdAt,
    updated_at: cart.updatedAt,
    items,
    item_count: items.reduce((total, item) => total + item.quantity, 0),
    total_amount: Number(items.reduce((total, item) => total + item.subtotal, 0).toFixed(2)),
  };
}

class Cart {
  static async getActive(memberId) {
    let cart = await prisma.cart.findFirst({
      where: { memberId, status: 'ACTIVE' },
      orderBy: { cartId: 'desc' },
      include: {
        items: {
          orderBy: { cartItemId: 'asc' },
          include: { product: true },
        },
      },
    });

    if (!cart) {
      try {
        cart = await prisma.cart.create({
          data: { memberId, status: 'ACTIVE' },
          include: { items: { include: { product: true } } },
        });
      } catch (error) {
        // The partial unique index can be reached by simultaneous first requests.
        if (error.code !== 'P2002') throw error;
        cart = await prisma.cart.findFirst({
          where: { memberId, status: 'ACTIVE' },
          orderBy: { cartId: 'desc' },
          include: { items: { include: { product: true } } },
        });
      }
    }

    return normaliseCart(cart);
  }

  static async addItem(memberId, productId, quantity) {
    const product = await prisma.product.findUnique({ where: { productId } });
    if (!product) throw new Error('Product not found.');
    if (!product.isAvailable) throw new Error('This product is currently unavailable.');

    const cart = await this.getActive(memberId);
    await prisma.cartItem.upsert({
      where: {
        cartId_productId: {
          cartId: cart.cart_id,
          productId,
        },
      },
      create: { cartId: cart.cart_id, productId, quantity },
      update: { quantity: { increment: quantity } },
    });

    return this.getActive(memberId);
  }

  static async updateItem(memberId, cartItemId, quantity) {
    const cart = await this.getActive(memberId);
    const item = await prisma.cartItem.findFirst({
      where: { cartItemId, cartId: cart.cart_id },
      include: { product: true },
    });

    if (!item) throw new Error('Cart item not found.');
    if (!item.product.isAvailable) throw new Error('This product is currently unavailable. Remove it before checkout.');

    if (quantity === 0) {
      await prisma.cartItem.delete({ where: { cartItemId } });
    } else {
      await prisma.cartItem.update({
        where: { cartItemId },
        data: { quantity },
      });
    }

    return this.getActive(memberId);
  }

  static async removeItem(memberId, cartItemId) {
    const cart = await this.getActive(memberId);
    const item = await prisma.cartItem.findFirst({
      where: { cartItemId, cartId: cart.cart_id },
      select: { cartItemId: true },
    });

    if (!item) throw new Error('Cart item not found.');
    await prisma.cartItem.delete({ where: { cartItemId } });
    return this.getActive(memberId);
  }
}

module.exports = Cart;
