import { JobController } from '../../../src/services/JobController';
import { RcloneModule } from '../../../src/native/RcloneModule';
import { updateFileStatus } from '../../../src/db';
import type { FileState } from '../../../src/types';

jest.mock('../../../src/native/RcloneModule', () => ({
  RcloneModule: {
    sync: jest.fn(),
    deleteRemotePath: jest.fn(),
    subscribeToJobStatus: jest.fn(),
  },
}));

jest.mock('../../../src/db', () => ({
  getDatabase: jest.fn(),
  updateFileStatus: jest.fn(),
}));

const mockRclone = RcloneModule as jest.Mocked<typeof RcloneModule>;
const mockUpdateFileStatus = updateFileStatus as jest.Mock;

describe('JobController', () => {
  const fileState: FileState = {
    id: 'f1',
    local_uri: 'file://img.jpg',
    cloud_path: 'EchoVault/img.jpg',
    rule_id: 'rule-1',
    status: 'PENDING',
    bytes: 100,
    attempts: 0,
    updated_at: '2026-08-01',
  };

  beforeEach(() => {
    jest.clearAllMocks();
  });

  it('handles successful sync', async () => {
    mockRclone.sync.mockResolvedValue('job-1');
    mockRclone.subscribeToJobStatus.mockImplementation((cb) => {
      // simulate success event immediately
      setTimeout(() => cb({ jobId: 'job-1', status: 'success' }), 10);
      return { remove: jest.fn() };
    });

    const controller = new JobController(fileState, 'remote-1');
    await controller.execute();

    expect(mockUpdateFileStatus).toHaveBeenCalledWith(undefined, 'f1', 'UPLOADING', undefined, true);
    expect(mockRclone.sync).toHaveBeenCalledWith('file://img.jpg', 'remote-1:EchoVault/img.jpg');
    expect(mockUpdateFileStatus).toHaveBeenCalledWith(undefined, 'f1', 'SYNCED', undefined, false);
  });

  it('retries on failure and eventually fails', async () => {
    jest.useFakeTimers();

    mockRclone.sync.mockResolvedValue('job-1');
    mockRclone.subscribeToJobStatus.mockImplementation((cb) => {
      // simulate error event
      setTimeout(() => cb({ jobId: 'job-1', status: 'error', error: 'Upload failed' }), 0);
      return { remove: jest.fn() };
    });

    const controller = new JobController(fileState, 'remote-1');
    
    const execPromise = controller.execute();
    
    // Attempt 0 fails, awaits backoff 1s
    await jest.advanceTimersByTimeAsync(1001);
    // Attempt 1 fails, awaits backoff 2s
    await jest.advanceTimersByTimeAsync(2001);
    // Attempt 2 fails, awaits backoff 4s
    await jest.advanceTimersByTimeAsync(4001);
    // Attempt 3 fails, awaits backoff 8s
    await jest.advanceTimersByTimeAsync(8001);
    
    await expect(execPromise).rejects.toThrow('Upload failed');

    expect(mockRclone.sync).toHaveBeenCalledTimes(4);
    expect(mockUpdateFileStatus).toHaveBeenLastCalledWith(undefined, 'f1', 'FAILED', 'Upload failed', false);
    
    jest.useRealTimers();
  });

  it('handles DELETED_LOCALLY files by deleting on remote', async () => {
    const deletedFile: FileState = { ...fileState, status: 'DELETED_LOCALLY' };
    const controller = new JobController(deletedFile, 'remote-1');

    await controller.execute();

    expect(mockRclone.deleteRemotePath).toHaveBeenCalledWith('remote-1', 'EchoVault/img.jpg');
    expect(mockUpdateFileStatus).toHaveBeenCalledWith(undefined, 'f1', 'SYNCED', undefined, false);
    expect(mockRclone.sync).not.toHaveBeenCalled();
  });

  it('aborts early if signal is aborted', async () => {
    const controller = new JobController(fileState, 'remote-1');
    const controllerAbort = new AbortController();
    controllerAbort.abort();

    await expect(controller.execute(controllerAbort.signal)).rejects.toThrow('Aborted');
    expect(mockRclone.sync).not.toHaveBeenCalled();
  });
});
