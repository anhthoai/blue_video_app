// import crypto from 'crypto'; // Not used in demo mode

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

export interface IPNNotification {
  btcAmount: string;
  sbpayMethod: string;
  txid: string;
  status: string;
  currencyCode: string;
  signature: string;
  extOrderId: string;
  btcTxid: string;
}

export class PaymentService {
  // @ts-ignore - Not used in demo mode
  private readonly apiKey: string;
  // @ts-ignore - Not used in demo mode
  private readonly secretKey: string;
  // @ts-ignore - Not used in demo mode
  private readonly baseUrl: string = 'http://mypremium.store';

  constructor() {
    this.apiKey = process.env['MPS_API_KEY'] || 'dusrpykr1uq2vq800bo3f8xm9dikzpj8';
    this.secretKey = process.env['MPS_SECRET_KEY'] || '3r4y9ug0mevqhv8h';
  }

  /**
   * Create a payment invoice
   */
  async createInvoice(request: PaymentRequest): Promise<PaymentResponse> {
    // For demo purposes, return mock payment data
    // In production, this would call the real payment API
    try {
      // Simulate API delay
      await new Promise(resolve => setTimeout(resolve, 1000));

      // Generate mock payment data
      const mockId = `demo_${Date.now()}_${Math.floor(Math.random() * 1000)}`;
      const mockAddress = `demo_address_${Math.random().toString(36).substring(2, 15)}`;

      return {
        id: mockId,
        paymentUri: `demo:${mockAddress}?amount=${request.usdAmount}`,
        currencyCode: request.targetCurrency,
        qrCode: 'demo_qr_code_base64_data',
        amount: request.usdAmount,
        status: 'OK',
        addr: mockAddress,
      };
    } catch (error) {
      console.error('Payment service error:', error);
      throw new Error('Failed to create payment invoice');
    }
  }

  /**
   * Verify IPN signature
   */
  verifyIPNSignature(_notification: IPNNotification): boolean {
    // For demo purposes, always return true
    // In production, this would verify the actual signature
    return true;
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
