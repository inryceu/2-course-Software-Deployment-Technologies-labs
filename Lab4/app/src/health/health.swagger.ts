import { applyDecorators } from '@nestjs/common';
import { ApiOperation, ApiResponse, ApiProduces } from '@nestjs/swagger';

export function ApiCheckAlive() {
  return applyDecorators(
    ApiOperation({ summary: 'Перевірка чи сервер працює (Liveness probe)' }),
    ApiProduces('text/plain'),
    ApiResponse({ status: 200, description: 'Повертає текстове "OK"' }),
  );
}

export function ApiCheckReady() {
  return applyDecorators(
    ApiOperation({
      summary: 'Перевірка готовності підключення до БД (Readiness probe)',
    }),
    ApiProduces('text/plain'),
    ApiResponse({
      status: 200,
      description: 'Підключення успішне, повертає "OK"',
    }),
    ApiResponse({
      status: 500,
      description: 'Помилка підключення до бази даних',
    }),
  );
}
