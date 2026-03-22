import { Injectable, OnModuleInit, OnModuleDestroy } from '@nestjs/common';
import { PrismaClient } from '@prisma/client';

@Injectable()
export class PrismaService extends PrismaClient implements /*OnModuleInit,*/ OnModuleDestroy {
  constructor() {
    const args = process.argv.slice(2);
    let host = '127.0.0.1';
    let port = '3306';
    let user = 'app';
    let password = '';
    let dbName = 'notes_db';

    args.forEach(arg => {
      if (arg.startsWith('--db-host=')) host = arg.split('=')[1];
      if (arg.startsWith('--db-port=')) port = arg.split('=')[1];
      if (arg.startsWith('--db-user=')) user = arg.split('=')[1];
      if (arg.startsWith('--db-password=')) password = arg.split('=')[1];
      if (arg.startsWith('--db-name=')) dbName = arg.split('=')[1];
    });

    const databaseUrl = `mysql://${user}:${password}@${host}:${port}/${dbName}`;

    super({
      datasources: {
        db: {
          url: databaseUrl,
        },
      },
    });
  }

  async onModuleInit() {
    await this.$connect();
  }

  async onModuleDestroy() {
    await this.$disconnect();
  }
}