import { Controller, Get, Res, HttpStatus } from '@nestjs/common';
import type { Response } from 'express';
import { PrismaService } from '../../prisma/prisma.service';
import { ApiTags } from '@nestjs/swagger';
import { ApiCheckAlive, ApiCheckReady } from './health.swagger';

@ApiTags('health')
@Controller('health')
export class HealthController {
  constructor(private readonly prisma: PrismaService) {}

  @Get('alive')
  @ApiCheckAlive()
  getAlive(@Res() res: Response) {
    return res.status(HttpStatus.OK).send('OK');
  }

  @Get('ready')
  @ApiCheckReady()
  async getReady(@Res() res: Response) {
    try {
      await this.prisma.$queryRaw`SELECT 1`;
      return res.status(HttpStatus.OK).send('OK');
    } catch {
      return res
        .status(HttpStatus.INTERNAL_SERVER_ERROR)
        .send('Database connection failed or database is not ready');
    }
  }
}
