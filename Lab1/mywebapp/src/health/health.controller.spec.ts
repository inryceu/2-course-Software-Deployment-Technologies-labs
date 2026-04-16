import { HttpStatus } from '@nestjs/common';
import { HealthController } from './health.controller';
import type { PrismaService } from '../../prisma/prisma.service';

describe('HealthController', () => {
  const prisma = {
    $queryRaw: jest.fn(),
  } as unknown as jest.Mocked<PrismaService>;

  let controller: HealthController;

  beforeEach(() => {
    jest.clearAllMocks();
    controller = new HealthController(prisma);
  });

  it('getAlive returns 200 with OK', () => {
    const res = {
      status: jest.fn().mockReturnThis(),
      send: jest.fn().mockReturnThis(),
    };

    controller.getAlive(res as never);

    expect(res.status).toHaveBeenCalledWith(HttpStatus.OK);
    expect(res.send).toHaveBeenCalledWith('OK');
  });

  it('getReady returns 200 when db query succeeds', async () => {
    prisma.$queryRaw.mockResolvedValue([1] as never);
    const res = {
      status: jest.fn().mockReturnThis(),
      send: jest.fn().mockReturnThis(),
    };

    await controller.getReady(res as never);

    expect(res.status).toHaveBeenCalledWith(HttpStatus.OK);
    expect(res.send).toHaveBeenCalledWith('OK');
  });

  it('getReady returns 500 when db query fails', async () => {
    prisma.$queryRaw.mockRejectedValue(new Error('db down'));
    const res = {
      status: jest.fn().mockReturnThis(),
      send: jest.fn().mockReturnThis(),
    };

    await controller.getReady(res as never);

    expect(res.status).toHaveBeenCalledWith(HttpStatus.INTERNAL_SERVER_ERROR);
    expect(res.send).toHaveBeenCalledWith(
      'Database connection failed or database is not ready',
    );
  });
});
