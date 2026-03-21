import { Injectable } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';
import { Note, Prisma } from '@prisma/client';

@Injectable()
export class NotesRepository {
  constructor(private readonly prisma: PrismaService) {}

  async findAll() {
    return this.prisma.note.findMany({
      select: {
        id: true,
        title: true,
      },
    });
  }

  async create(data: Prisma.NoteCreateInput): Promise<Note> {
    return this.prisma.note.create({
      data,
    });
  }

  async findById(id: number): Promise<Note | null> {
    return this.prisma.note.findUnique({
      where: { id },
    });
  }
}
