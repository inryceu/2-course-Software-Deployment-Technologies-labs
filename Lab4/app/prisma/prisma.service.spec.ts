describe('PrismaService', () => {
  const originalEnv = process.env.DATABASE_URL;

  afterEach(() => {
    if (originalEnv === undefined) {
      delete process.env.DATABASE_URL;
    } else {
      process.env.DATABASE_URL = originalEnv;
    }
    jest.resetModules();
  });

  it('throws when DATABASE_URL is missing', async () => {
    delete process.env.DATABASE_URL;
    const { PrismaService } = await import('./prisma.service');

    expect(() => new PrismaService()).toThrow(
      'DATABASE_URL is not defined in environment',
    );
  });
});
