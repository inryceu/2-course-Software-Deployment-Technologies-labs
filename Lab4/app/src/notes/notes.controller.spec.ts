import { HttpStatus } from '@nestjs/common';
import { NotesController } from './notes.controller';
import type { NotesService } from './notes.service';

describe('NotesController', () => {
  const notesService = {
    findAll: jest.fn(),
    create: jest.fn(),
    findOne: jest.fn(),
  } as unknown as jest.Mocked<NotesService>;

  let controller: NotesController;

  beforeEach(() => {
    jest.clearAllMocks();
    controller = new NotesController(notesService);
  });

  it('findAll returns html table when accept contains text/html', async () => {
    notesService.findAll.mockResolvedValue([{ id: 1, title: 'A' }]);
    const res = {
      type: jest.fn().mockReturnThis(),
      send: jest.fn().mockReturnThis(),
      json: jest.fn().mockReturnThis(),
    };

    await controller.findAll(
      { headers: { accept: 'text/html' } } as never,
      res as never,
    );

    expect(res.type).toHaveBeenCalledWith('html');
    expect(res.send).toHaveBeenCalledWith(expect.stringContaining('<table'));
  });

  it('findAll returns json by default', async () => {
    notesService.findAll.mockResolvedValue([
      { id: 1, title: 'A', content: 'x' },
    ]);
    const res = {
      json: jest.fn().mockReturnThis(),
      type: jest.fn().mockReturnThis(),
      send: jest.fn().mockReturnThis(),
    };

    await controller.findAll({ headers: {} } as never, res as never);

    expect(res.json).toHaveBeenCalledWith([{ id: 1, title: 'A' }]);
  });

  it('create returns created note with 201', async () => {
    const created = { id: 5, title: 'T', content: 'C' };
    notesService.create.mockResolvedValue(created as never);
    const res = {
      status: jest.fn().mockReturnThis(),
      json: jest.fn().mockReturnThis(),
    };

    await controller.create({ title: 'T', content: 'C' }, res as never);

    expect(res.status).toHaveBeenCalledWith(HttpStatus.CREATED);
    expect(res.json).toHaveBeenCalledWith(created);
  });

  it('findOne returns 404 when note not found', async () => {
    notesService.findOne.mockResolvedValue(null);
    const res = {
      status: jest.fn().mockReturnThis(),
      send: jest.fn().mockReturnThis(),
      type: jest.fn().mockReturnThis(),
      json: jest.fn().mockReturnThis(),
    };

    await controller.findOne('7', { headers: {} } as never, res as never);

    expect(res.status).toHaveBeenCalledWith(HttpStatus.NOT_FOUND);
    expect(res.send).toHaveBeenCalled();
  });

  it('findOne returns html when accept contains text/html', async () => {
    notesService.findOne.mockResolvedValue({
      id: 2,
      title: 'T',
      content: 'C',
      created_at: new Date('2026-01-01T00:00:00.000Z'),
    } as never);
    const res = {
      type: jest.fn().mockReturnThis(),
      send: jest.fn().mockReturnThis(),
      json: jest.fn().mockReturnThis(),
      status: jest.fn().mockReturnThis(),
    };

    await controller.findOne(
      '2',
      { headers: { accept: 'text/html' } } as never,
      res as never,
    );

    expect(res.type).toHaveBeenCalledWith('html');
    expect(res.send).toHaveBeenCalledWith(expect.stringContaining('<table'));
  });

  it('findOne returns json by default', async () => {
    const note = { id: 3, title: 'T', content: 'C', created_at: new Date() };
    notesService.findOne.mockResolvedValue(note as never);
    const res = {
      json: jest.fn().mockReturnThis(),
      type: jest.fn().mockReturnThis(),
      send: jest.fn().mockReturnThis(),
      status: jest.fn().mockReturnThis(),
    };

    await controller.findOne(
      '3',
      { headers: { accept: 'application/json' } } as never,
      res as never,
    );

    expect(res.json).toHaveBeenCalledWith(note);
  });
});
