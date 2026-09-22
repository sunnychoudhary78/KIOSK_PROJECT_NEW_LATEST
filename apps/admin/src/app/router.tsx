import { BrowserRouter, Navigate, Route, Routes } from 'react-router-dom';
import { AuthProvider } from '../core/auth/AuthProvider';
import { LoginPage } from '../features/auth/LoginPage';
import { DashboardPage } from '../features/dashboard/DashboardPage';
import { KiosksPage } from '../features/kiosks/KiosksPage';
import { ServicesPage } from '../features/services/ServicesPage';
import { PrintJobsPage } from '../features/print-jobs/PrintJobsPage';
import { DigiLockerPage } from '../features/digilocker/DigiLockerPage';
import { AuditLogsPage } from '../features/audit-logs/AuditLogsPage';
import { RecordingsPage } from '../features/surveillance/RecordingsPage';
import { UsersPage } from '../features/users/UsersPage';
import { PlatformSettingsPage } from '../features/platform-settings/PlatformSettingsPage';
import { AdvertisersPage } from '../features/ads/AdvertisersPage';
import { AdvertiserDetailPage } from '../features/ads/AdvertiserDetailPage';
import { CampaignsPage } from '../features/ads/CampaignsPage';
import { CampaignWizardPage } from '../features/ads/CampaignWizardPage';
import { CampaignDetailPage } from '../features/ads/CampaignDetailPage';
import { AppShell } from './AppShell';

export function AppRouter() {
  return (
    <BrowserRouter>
      <AuthProvider>
        <Routes>
          <Route path="/login" element={<LoginPage />} />
          <Route element={<AppShell />}>
            <Route index element={<DashboardPage />} />
            <Route path="kiosks" element={<KiosksPage />} />
            <Route path="advertisers" element={<AdvertisersPage />} />
            <Route path="advertisers/:id" element={<AdvertiserDetailPage />} />
            <Route path="campaigns" element={<CampaignsPage />} />
            <Route path="campaigns/new" element={<CampaignWizardPage />} />
            <Route path="campaigns/:id" element={<CampaignDetailPage />} />
            <Route path="services" element={<ServicesPage />} />
            <Route path="print-jobs" element={<PrintJobsPage />} />
            <Route path="digilocker" element={<DigiLockerPage />} />
            <Route path="recordings" element={<RecordingsPage />} />
            <Route path="audit-logs" element={<AuditLogsPage />} />
            <Route path="users" element={<UsersPage />} />
            <Route path="platform-settings" element={<PlatformSettingsPage />} />
          </Route>
          <Route path="*" element={<Navigate to="/" replace />} />
        </Routes>
      </AuthProvider>
    </BrowserRouter>
  );
}
