import type { ComponentTone } from './fleetHealth';

export function toneClass(tone: ComponentTone) {
  switch (tone) {
    case 'ok':
      return 'bg-emerald-50 text-emerald-800 border-emerald-200';
    case 'warn':
      return 'bg-amber-50 text-amber-900 border-amber-200';
    case 'error':
      return 'bg-red-50 text-red-800 border-red-200';
    case 'offline':
      return 'bg-slate-100 text-slate-600 border-slate-200';
    default:
      return 'bg-muted text-muted-foreground border-border';
  }
}

export function toneLabel(tone: ComponentTone) {
  switch (tone) {
    case 'ok':
      return 'Healthy';
    case 'warn':
      return 'Warning';
    case 'error':
      return 'Fault';
    case 'offline':
      return 'Offline';
    default:
      return 'Unknown';
  }
}
