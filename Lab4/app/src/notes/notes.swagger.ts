import { applyDecorators } from '@nestjs/common';
import {
  ApiOperation,
  ApiResponse,
  ApiProduces,
  ApiHeader,
  ApiBody,
  ApiProperty,
} from '@nestjs/swagger';

export class CreateNoteDto {
  @ApiProperty({ example: 'Купити молоко', description: 'Заголовок нотатки' })
  title: string;

  @ApiProperty({
    example: 'Треба зайти в АТБ після пар',
    description: 'Вміст нотатки',
  })
  content: string;
}

export function ApiFindAllNotes() {
  return applyDecorators(
    ApiOperation({ summary: 'Отримати список усіх нотаток' }),
    ApiHeader({
      name: 'Accept',
      description:
        'Вкажіть text/html для отримання таблиці, або application/json',
      required: false,
    }),
    ApiProduces('application/json', 'text/html'),
    ApiResponse({ status: 200, description: 'Список нотаток (id, title)' }),
  );
}

export function ApiCreateNote() {
  return applyDecorators(
    ApiOperation({ summary: 'Створити нову нотатку' }),
    ApiBody({ type: CreateNoteDto }),
    ApiResponse({ status: 201, description: 'Нотатку успішно створено' }),
  );
}

export function ApiFindOneNote() {
  return applyDecorators(
    ApiOperation({ summary: 'Отримати повну інформацію про нотатку за ID' }),
    ApiHeader({
      name: 'Accept',
      description:
        'Вкажіть text/html для отримання таблиці, або application/json',
      required: false,
    }),
    ApiProduces('application/json', 'text/html'),
    ApiResponse({ status: 200, description: 'Повна інформація про нотатку' }),
    ApiResponse({ status: 404, description: 'Нотатку не знайдено' }),
  );
}
