import crypto from 'crypto';

export interface PaymentRequest {
  usdAmount: number;
  extOrderId: string;
  targetCurrency?: string;
}

export interface PaymentResponse {
  id: string;
  paymentUri: string;
  currencyCode: string;
  qrCode: string;
  amount: number;
  status: string;
  addr: string;
}

export interface IPNNotification {
  order_id?: string;
  track_id?: string;
  status: string;
  txid?: string;
  currency?: string;
  network?: string;
  amount?: string;
  paid_amount?: string;
  type?: string;

  // Legacy fields kept for backward compatibility with old payload shapes.
  sbpayMethod?: string;
  currencyCode?: string;
  signature?: string;
  extOrderId?: string;
  btcTxid?: string;
}

export class PaymentService {
  private readonly merchantApiKey: string;
  private readonly callbackToken: string;
  private readonly baseUrl: string = 'https://api.oxapay.com/v1';

  constructor() {
    this.merchantApiKey = process.env['OXAPAY_MERCHANT_API_KEY'] || '';
    this.callbackToken = process.env['OXAPAY_CALLBACK_TOKEN'] || '';
  }

  /**
   * Create an OxaPay USDT (TRC20) payment invoice.
   */
  async createInvoice(request: PaymentRequest): Promise<PaymentResponse> {
    try {
      if (!this.merchantApiKey) {
        throw new Error('OXAPAY_MERCHANT_API_KEY is not configured');
      }

      const callbackBaseUrl = this.resolveHttpUrl(
        process.env['PUBLIC_API_URL'],
        process.env['BASE_URL'] || 'https://api.onlybl.com',
      );
      const callbackTokenQuery = this.callbackToken
        ? `?token=${encodeURIComponent(this.callbackToken)}`
        : '';
      const appReturnUrlBase = this.resolveHttpUrl(
        process.env['OXAPAY_RETURN_URL'],
        `${callbackBaseUrl}/payment-return`,
      );
      const returnUrl = appReturnUrlBase.includes('?')
        ? `${appReturnUrlBase}&orderId=${encodeURIComponent(request.extOrderId)}`
        : `${appReturnUrlBase}?orderId=${encodeURIComponent(request.extOrderId)}`;

      const payload = {
        amount: Number(request.usdAmount.toFixed(2)),
        currency: 'USDT',
        to_currency: 'USDT',
        lifetime: 60,
        fee_paid_by_payer: 1,
        order_id: request.extOrderId,
        callback_url: `${callbackBaseUrl}/api/v1/payment/ipn${callbackTokenQuery}`,
        return_url: returnUrl,
        description: `USDT TRC20 payment for order ${request.extOrderId}`,
      };

      console.log('🔗 Creating OxaPay USDT invoice:', {
        usdAmount: request.usdAmount,
        extOrderId: request.extOrderId,
        currency: 'USDT',
      });

      const response = await fetch(`${this.baseUrl}/payment/invoice`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          merchant_api_key: this.merchantApiKey,
        },
        body: JSON.stringify(payload),
      });

      const data = await response.json() as any;
      console.log('🔗 OxaPay invoice response:', data);

      if (!response.ok || data.status !== 200 || !data.data?.track_id || !data.data?.payment_url) {
        throw new Error(data?.message || data?.error?.message || 'Failed to create OxaPay invoice');
      }

      return {
        id: String(data.data.track_id),
        paymentUri: String(data.data.payment_url),
        currencyCode: 'USDT',
        qrCode: '',
        amount: Number(request.usdAmount.toFixed(2)),
        status: 'PENDING',
        addr: '',
      };
    } catch (error) {
      console.error('❌ OxaPay USDT invoice creation error:', error);
      throw new Error('Failed to create OxaPay USDT payment invoice');
    }
  }

  private resolveHttpUrl(value: string | undefined, fallback: string): string {
    const candidate = String(value || '').trim();
    const fallbackValue = String(fallback || '').trim();

    const normalize = (urlValue: string): string | null => {
      if (!urlValue) return null;
      try {
        const parsed = new URL(urlValue);
        if (parsed.protocol === 'http:' || parsed.protocol === 'https:') {
          return parsed.toString().replace(/\/$/, '');
        }
      } catch {
        return null;
      }
      return null;
    };

    return (
      normalize(candidate) ||
      normalize(fallbackValue) ||
      'https://api.onlybl.com'
    );
  }

  /**
   * Verify callback token sent to callback endpoint.
   */
  verifyCallbackToken(token?: string): boolean {
    if (!this.callbackToken) {
      return true;
    }

    if (!token) {
      return false;
    }

    if (token.length !== this.callbackToken.length) {
      return false;
    }

    return crypto.timingSafeEqual(
      Buffer.from(token),
      Buffer.from(this.callbackToken),
    );
  }

  /**
   * Normalize payment notification fields to internal values.
   */
  normalizeNotification(notification: IPNNotification): {
    extOrderId: string;
    status: string;
    txid: string;
    currencyCode: string;
    paymentMethod: 'USDT';
  } {
    const extOrderId = notification.order_id || notification.extOrderId || '';
    const txid = notification.txid || notification.btcTxid || '';
    const currencyCode = (notification.currency || notification.currencyCode || 'USDT').toUpperCase();

    return {
      extOrderId,
      status: notification.status,
      txid,
      currencyCode,
      paymentMethod: 'USDT',
    };
  }

  /**
   * Determine whether callback status should be treated as paid.
   */
  isCompletedStatus(status: string): boolean {
    const normalized = String(status || '').toUpperCase();
    return ['PAID', 'COMPLETED', 'CONFIRMED', 'OK'].includes(normalized);
  }

  /**
   * Convert USD to coins (1 USD = 100 coins)
   */
  usdToCoins(usdAmount: number): number {
    return Math.round(usdAmount * 100);
  }

  /**
   * Convert coins to USD (100 coins = 1 USD)
   */
  coinsToUsd(coins: number): number {
    return coins / 100;
  }

  /**
   * Get coin packages with USD prices
   */
  getCoinPackages() {
    return [
      //{ coins: 100, usd: 1.00, label: '100 Coins' },
      //{ coins: 200, usd: 2.00, label: '200 Coins' },
      //{ coins: 500, usd: 5.00, label: '500 Coins' },
      { coins: 1000, usd: 10.00, label: '1000 Coins' },
      { coins: 2000, usd: 20.00, label: '2000 Coins' },
      { coins: 10000, usd: 100.00, label: '10000 Coins' },
    ];
  }
}

export const paymentService = new PaymentService();
