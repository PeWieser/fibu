import { JobController } from '../../../src/services/JobController';
import { RcloneModule } from '../../../src/native/RcloneModule';
import { updateFileStatus } from '../../../src/db';
import type { FileState } from '../../../src/types';

jest.mock('expo-modules-core', () => ({
  requireNativeModule: jest.fn(),
  EventEmitter: class { addListener = jest.fn() }
}));
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
    mockRclone.sync.mockResolvedValue('job-1');
    mockRclone.subscribeToJobStatus.mockImplementation((cb) => {
      Promise.resolve().then(() => {
        cb({ jobId: 'job-1', status: 'error', error: 'Upload failed' });
      });
      return { remove: jest.fn() };
    });

    // Mock setTimeout so backoff doesn't actually wait
    jest.spyOn(global, 'setTimeout').mockImplementation((fn: unknown) => {
      (fn as () => void)();
      return 0 as unknown as ReturnType<typeof setTimeout>;
    });

    const controller = new JobController(fileState, 'remote-1');
    await expect(controller.execute()).rejects.toThrow('Upload failed');

    expect(mockRclone.sync).toHaveBeenCalledTimes(4);
    expect(mockUpdateFileStatus).toHaveBeenLastCalledWith(undefined, 'f1', 'FAILED', 'Upload failed', false);
    
    (global.setTimeout as unknown as jest.Mock).mockRestore();
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
