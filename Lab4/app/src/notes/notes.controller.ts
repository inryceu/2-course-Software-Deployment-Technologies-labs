import {
  Controller,
  Get,
  Post,
  Body,
  Param,
  Req,
  Res,
  HttpStatus,
} from '@nestjs/common';
import type { Request, Response } from 'express';
import { NotesService } from './notes.service';
import { ApiTags } from '@nestjs/swagger';
import {
  ApiFindAllNotes,
  ApiCreateNote,
  ApiFindOneNote,
} from './notes.swagger';

@ApiTags('notes')
@Controller('notes')
export class NotesController {
  constructor(private readonly notesService: NotesService) {}

  @Get()
  @ApiFindAllNotes()
  async findAll(@Req() req: Request, @Res() res: Response) {
    const notes = await this.notesService.findAll();
    const accept = req.headers.accept || '';

    if (accept.includes('text/html')) {
      let html = '<table border="1"><tr><th>ID</th><th>Title</th></tr>';
      html += notes
        .map((n) => `<tr><td>${n.id}</td><td>${n.title}</td></tr>`)
        .join('');
      html += '</table>';
      return res.type('html').send(html);
    }

    return res.json(notes.map((n) => ({ id: n.id, title: n.title })));
  }

  @Post()
  @ApiCreateNote()
  async create(
    @Body() body: { title: string; content: string },
    @Res() res: Response,
  ) {
    const note = await this.notesService.create(body.title, body.content);
    return res.status(HttpStatus.CREATED).json(note);
  }

  @Get(':id')
  @ApiFindOneNote()
  async findOne(
    @Param('id') id: string,
    @Req() req: Request,
    @Res() res: Response,
  ) {
    const note = await this.notesService.findOne(+id);
    if (!note) return res.status(HttpStatus.NOT_FOUND).send();

    const accept = req.headers.accept || '';
    if (accept.includes('text/html')) {
      const html = `<table border="1">
        <tr><th>ID</th><td>${note.id}</td></tr>
        <tr><th>Title</th><td>${note.title}</td></tr>
        <tr><th>Content</th><td>${note.content}</td></tr>
        <tr><th>Created At</th><td>${note.created_at.toISOString()}</td></tr>
      </table>`;
      return res.type('html').send(html);
    }

    return res.json(note);
  }
}
