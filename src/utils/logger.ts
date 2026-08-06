const REDACT_PATTERN = /(rclone:|pass=|token=|key=|secret=|password=)(\S+)/gi;

function redact(message: string): string {
  if (typeof message !== 'string') return message;
  return message.replace(REDACT_PATTERN, '$1[REDACTED]');
}

export const Logger = {
  info: (message: string, meta?: unknown) => {
    // eslint-disable-next-line no-console
    console.info(redact(message), meta);
  },
  warn: (message: string, meta?: unknown) => {
    console.warn(redact(message), meta);
  },
  error: (message: string, meta?: unknown) => {
    console.error(redact(message), meta);
  },
};
