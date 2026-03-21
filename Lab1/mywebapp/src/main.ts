import { NestFactory } from '@nestjs/core';
import { AppModule } from './app.module';
import { setupSwagger } from './swagger.config';

async function bootstrap() {
  const app = await NestFactory.create(AppModule);

  setupSwagger(app);

  if (process.env.LISTEN_FDS && parseInt(process.env.LISTEN_FDS, 10) > 0) {
    console.log('Starting via Systemd Socket Activation (FD 3)');
    await app.listen(3);
  } else {
    console.log('Starting via standard port binding (5200)');
    await app.listen(5200, '127.0.0.1');
  }
}
bootstrap();
