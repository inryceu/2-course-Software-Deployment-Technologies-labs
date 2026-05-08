import { NotesService } from './notes.service';
import type { NotesRepository } from './notes.repository';

describe('NotesService', () => {
  const repository = {
    findAll: jest.fn(),
    create: jest.fn(),
    findById: jest.fn(),
  } as unknown as jest.Mocked<NotesRepository>;

  let service: NotesService;

  beforeEach(() => {
    jest.clearAllMocks();
    service = new NotesService(repository);
  });

  it('findAll delegates to repository', async () => {
    repository.findAll.mockResolvedValue([{ id: 1, title: 'n1' }]);
    await expect(service.findAll()).resolves.toEqual([{ id: 1, title: 'n1' }]);
    expect(repository.findAll.mock.calls.length).toBe(1);
  });

  it('create delegates to repository with dto shape', async () => {
    const created = { id: 1, title: 't', content: 'c' };
    repository.create.mockResolvedValue(created as never);

    await expect(service.create('t', 'c')).resolves.toEqual(created);
    expect(repository.create.mock.calls[0]).toEqual([
      {
        title: 't',
        content: 'c',
      },
    ]);
  });

  it('findOne delegates to repository by id', async () => {
    repository.findById.mockResolvedValue(null);
    await expect(service.findOne(123)).resolves.toBeNull();
    expect(repository.findById.mock.calls[0]).toEqual([123]);
  });
});
