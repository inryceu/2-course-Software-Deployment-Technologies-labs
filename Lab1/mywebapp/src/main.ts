import { NestFactory } from '@nestjs/core';
import { AppModule } from './app.module';
import { setupSwagger } from './swagger.config';

async function bootstrap() {
  const app = await NestFactory.create(AppModule);

  setupSwagger(app);

  console.log('DEBUG: LISTEN_FDS =', process.env.LISTEN_FDS);

  const listenFds = parseInt(process.env.LISTEN_FDS ?? '0', 10);

  if (listenFds > 0) {
    console.log('Starting via Systemd Socket Activation (FD 3)');
    await app.getHttpServer().listen({ fd: 3 });
  } else {
    const port = 5200;
    const host = '127.0.0.1';
    console.log(`Starting via standard port binding (${host}:${port})`);
    await app.listen(port, host);
  }
}
bootstrap();
