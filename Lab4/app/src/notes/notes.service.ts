import { Injectable } from '@nestjs/common';
import { NotesRepository } from './notes.repository';
import { Note } from '@prisma/client';

@Injectable()
export class NotesService {
  constructor(private readonly repository: NotesRepository) {}

  async findAll(): Promise<Partial<Note>[]> {
    return this.repository.findAll();
  }

  async create(title: string, content: string): Promise<Note> {
    return this.repository.create({
      title,
      content,
    });
  }

  async findOne(id: number): Promise<Note | null> {
    return this.repository.findById(id);
  }
}
