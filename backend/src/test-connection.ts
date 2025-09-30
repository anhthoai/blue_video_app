import prisma from './lib/prisma';

async function testConnection() {
  try {
    console.log('Testing database connection...');
    await prisma.$connect();
    console.log('✅ Database connected successfully!');
    
    // Test a simple query
    const userCount = await prisma.user.count();
    console.log(`📊 Current users in database: ${userCount}`);
    
    await prisma.$disconnect();
    console.log('✅ Database disconnected');
  } catch (error) {
    console.error('❌ Database connection failed:', error);
    process.exit(1);
  }
}

testConnection();
