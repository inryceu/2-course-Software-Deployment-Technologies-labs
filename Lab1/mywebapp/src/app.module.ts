import { Module } from '@nestjs/common';
import { AppController } from './app.controller';
import { AppService } from './app.service';
import { NotesModule } from './notes/notes.module';
import { HealthModule } from './health/health.module';

@Module({
  imports: [NotesModule, HealthModule],
  controllers: [AppController],
  providers: [AppService],
})
export class AppModule {}
