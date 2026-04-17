import { AppService } from './app.service';

describe('AppService', () => {
  it('returns hello world text', () => {
    const service = new AppService();
    expect(service.getHello()).toBe('Hello World!');
  });

  /*
  it('demo case: merge should be blocked by failing test', () => {
    const service = new AppService();
    expect(service.getDemoMergeValue()).toBe(11);
  });
  */
});
