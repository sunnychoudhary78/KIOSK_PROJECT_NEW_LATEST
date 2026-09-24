import { TooltipProvider } from '@/components/ui/tooltip';
import { Toaster } from '@/components/ui/sonner';
import { AppRouter } from './router';
import '../styles.css';

export function App() {
  return (
    <TooltipProvider>
      <AppRouter />
      <Toaster />
    </TooltipProvider>
  );
}
