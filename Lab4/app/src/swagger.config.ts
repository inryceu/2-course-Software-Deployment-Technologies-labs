import { DocumentBuilder, SwaggerModule } from '@nestjs/swagger';
import { INestApplication } from '@nestjs/common';

export function setupSwagger(app: INestApplication): void {
  const config = new DocumentBuilder()
    .setTitle('Notes Service API')
    .setDescription(
      'Документація API для лабораторної роботи №1 (Notes Service)',
    )
    .setVersion('1.0')
    .addTag('notes', 'Ендпоінти бізнес-логіки для керування нотатками')
    .addTag('health', 'Службові ендпоінти для перевірки стану системи')
    .build();

  const document = SwaggerModule.createDocument(app, config);

  SwaggerModule.setup('api/docs', app, document);
}
