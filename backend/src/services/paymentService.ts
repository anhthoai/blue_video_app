import crypto from 'crypto';

export interface PaymentRequest {
  usdAmount: number;
  extOrderId: string;
  targetCurrency: string;
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

export interface CreditCardPaymentRequest {
  amount: number;
  currency: string;
  extOrderId: string;
  email: string;
  productName: string;
}

export interface CreditCardPaymentResponse {
  transId: string;
  amount: string;
  amountTry?: string;
  status: string;
  endpointUrl: string;
  sign: string;
}

export interface IPNNotification {
  btcAmount?: string;
  sbpayMethod: string;
  txid: string;
  status: string;
  currencyCode: string;
  signature: string;
  extOrderId: string;
  btcTxid?: string;
  usdAmount?: string;
  prerequest?: string;
}

export class PaymentService {
  private readonly apiKey: string;
  private readonly secretKey: string;
  private readonly baseUrl: string = 'http://mypremium.store';

  constructor() {
    this.apiKey = process.env['MPS_API_KEY'] || 'dusrpykr1uq2vq800bo3f8xm9dikzpj8';
    this.secretKey = process.env['MPS_SECRET_KEY'] || '3r4y9ug0mevqhv8h';
  }

  /**
   * Create a USDT (cryptocurrency) payment invoice
   */
  async createInvoice(request: PaymentRequest): Promise<PaymentResponse> {
    try {
      const formData = new URLSearchParams();
      formData.append('op', 'create_invoice');
      formData.append('api_key', this.apiKey);
      formData.append('usd_amount', request.usdAmount.toString());
      formData.append('ext_order_id', request.extOrderId);
      formData.append('gen_qr_code', '1');
      formData.append('target_currency', request.targetCurrency);

      console.log('🔗 Creating USDT invoice:', {
        usdAmount: request.usdAmount,
        extOrderId: request.extOrderId,
        targetCurrency: request.targetCurrency,
      });

      const response = await fetch(this.baseUrl, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: formData,
      });

      const data = await response.json() as any;
      console.log('🔗 USDT invoice response:', data);

      if (data.status !== 'OK') {
        throw new Error(data.error || 'Failed to create invoice');
      }

      return {
        id: data.id.toString(),
        paymentUri: data.payment_uri || '',
        currencyCode: data.currency_code,
        qrCode: data.qr_code,
        amount: data.amount,
        status: data.status,
        addr: data.addr,
      };
    } catch (error) {
      console.error('❌ USDT invoice creation error:', error);
      throw new Error('Failed to create USDT payment invoice');
    }
  }

  /**
   * Create a Credit Card payment invoice
   */
  async createCreditCardInvoice(request: CreditCardPaymentRequest): Promise<CreditCardPaymentResponse> {
    try {
      const formData = new URLSearchParams();
      formData.append('op', 'cc_checkout');
      formData.append('api_key', this.apiKey);
      formData.append('api_ver', '1.2');
      formData.append('amount', request.amount.toString());
      formData.append('currency', request.currency);
      formData.append('ext_order_id', request.extOrderId);
      formData.append('success_uri', `${process.env['BASE_URL'] || 'http://localhost:3000'}/payment/success`);
      formData.append('fail_uri', `${process.env['BASE_URL'] || 'http://localhost:3000'}/payment/fail`);
      formData.append('email', request.email);
      formData.append('product_name', request.productName);

      console.log('💳 Creating Credit Card invoice:', {
        amount: request.amount,
        currency: request.currency,
        extOrderId: request.extOrderId,
        email: request.email,
      });

      const response = await fetch(this.baseUrl, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: formData,
      });

      const data = await response.json() as any;
      console.log('💳 Credit Card invoice response:', data);

      if (data.status !== 'OK') {
        throw new Error(data.error || 'Failed to create credit card invoice');
      }

      return {
        transId: data.trans_id,
        amount: data.amount,
        amountTry: data.amount_try,
        status: data.status,
        endpointUrl: data.endpoint_url,
        sign: data.sign,
      };
    } catch (error) {
      console.error('❌ Credit Card invoice creation error:', error);
      throw new Error('Failed to create credit card payment invoice');
    }
  }

  /**
   * Verify IPN signature for cryptocurrency payments
   */
  verifyCryptoIPNSignature(notification: IPNNotification): boolean {
    try {
      // Sort keys alphabetically (excluding 'signature')
      const sortedKeys = Object.keys(notification)
        .filter(key => key !== 'signature')
        .sort();

      // Create payload by concatenating values in sorted order
      let payload = '';
      for (const key of sortedKeys) {
        payload += notification[key as keyof IPNNotification] || '';
      }

      // Append secret key
      payload += this.secretKey;

      // Calculate SHA256 hash
      const calculatedSignature = crypto
        .createHash('sha256')
        .update(payload)
        .digest('hex');

      console.log('🔐 IPN signature verification:', {
        payload: payload.substring(0, 100) + '...',
        calculatedSignature,
        receivedSignature: notification.signature,
        match: calculatedSignature === notification.signature,
      });

      return calculatedSignature === notification.signature;
    } catch (error) {
      console.error('❌ IPN signature verification error:', error);
      return false;
    }
  }

  /**
   * Verify IPN signature for credit card payments
   */
  verifyCreditCardIPNSignature(notification: IPNNotification): boolean {
    try {
      // Sort keys alphabetically (excluding 'signature')
      const sortedKeys = Object.keys(notification)
        .filter(key => key !== 'signature')
        .sort();

      // Create payload by concatenating values in sorted order
      let payload = '';
      for (const key of sortedKeys) {
        payload += notification[key as keyof IPNNotification] || '';
      }

      // Append secret key
      payload += this.secretKey;

      // Calculate SHA256 hash
      const calculatedSignature = crypto
        .createHash('sha256')
        .update(payload)
        .digest('hex');

      console.log('🔐 Credit Card IPN signature verification:', {
        payload: payload.substring(0, 100) + '...',
        calculatedSignature,
        receivedSignature: notification.signature,
        match: calculatedSignature === notification.signature,
      });

      return calculatedSignature === notification.signature;
    } catch (error) {
      console.error('❌ Credit Card IPN signature verification error:', error);
      return false;
    }
  }

  /**
   * Verify IPN signature (generic method)
   */
  verifyIPNSignature(notification: IPNNotification): boolean {
    if (notification.sbpayMethod === 'bitcoin' || notification.sbpayMethod === 'cryptocurrency') {
      return this.verifyCryptoIPNSignature(notification);
    } else if (notification.sbpayMethod === 'creditcard') {
      return this.verifyCreditCardIPNSignature(notification);
    }
    
    console.warn('⚠️ Unknown payment method:', notification.sbpayMethod);
    return false;
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
      { coins: 100, usd: 1.00, label: '100 Coins' },
      { coins: 200, usd: 2.00, label: '200 Coins' },
      { coins: 500, usd: 5.00, label: '500 Coins' },
      { coins: 1000, usd: 10.00, label: '1000 Coins' },
      { coins: 2000, usd: 20.00, label: '2000 Coins' },
      { coins: 10000, usd: 100.00, label: '10000 Coins' },
    ];
  }
}

export const paymentService = new PaymentService();
