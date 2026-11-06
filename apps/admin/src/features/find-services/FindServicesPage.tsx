import { useCallback, useEffect, useState, type FormEvent } from 'react';
import { apiRequest } from '../../core/api/client';
import { useAuth } from '../../core/auth/auth-context';
import { Button, EmptyState, Input, PageHeader, Panel } from '../../core/ui/primitives';

type LocalContact = {
  id: string;
  name: string;
  phone: string;
  sortOrder: number;
};

type LocalCategory = {
  id: string;
  slug: string;
  name: string;
  sortOrder: number;
  contacts: LocalContact[];
};

type LocalList = {
  categories: LocalCategory[];
};

export function FindServicesPage() {
  const { token } = useAuth();
  const [list, setList] = useState<LocalList | null>(null);
  const [loading, setLoading] = useState(false);
  const [listError, setListError] = useState<string | null>(null);
  const [serviceName, setServiceName] = useState('');
  const [savingService, setSavingService] = useState(false);
  const [formError, setFormError] = useState<string | null>(null);
  const [removingId, setRemovingId] = useState<string | null>(null);
  const [selectedId, setSelectedId] = useState<string | null>(null);
  const [contactName, setContactName] = useState('');
  const [contactPhone, setContactPhone] = useState('');
  const [savingContact, setSavingContact] = useState(false);
  const [contactError, setContactError] = useState<string | null>(null);
  const [removingContactId, setRemovingContactId] = useState<string | null>(null);

  const loadList = useCallback(async () => {
    setLoading(true);
    setListError(null);
    try {
      const result = await apiRequest<LocalList>('/local-services', { token });
      setList(result);
      setSelectedId((current) => {
        if (current && result.categories.some((item) => item.id === current)) return current;
        return result.categories[0]?.id ?? null;
      });
    } catch (err) {
      setListError(err instanceof Error ? err.message : 'Failed to load services');
      setList(null);
    } finally {
      setLoading(false);
    }
  }, [token]);

  useEffect(() => {
    void loadList();
  }, [loadList]);

  const selected = list?.categories.find((item) => item.id === selectedId) ?? null;

  async function addService(event: FormEvent) {
    event.preventDefault();
    setSavingService(true);
    setFormError(null);
    try {
      const created = await apiRequest<LocalCategory>('/local-services', {
        method: 'POST',
        token,
        body: { name: serviceName.trim() },
      });
      setServiceName('');
      await loadList();
      setSelectedId(created.id);
    } catch (err) {
      setFormError(err instanceof Error ? err.message : 'Failed to add service');
    } finally {
      setSavingService(false);
    }
  }

  async function removeService(item: LocalCategory) {
    const count = item.contacts.length;
    const extra = count === 0 ? '' : ` and its ${count} phone ${count === 1 ? 'number' : 'numbers'}`;
    if (!window.confirm(`Remove “${item.name}”${extra} from Find Services?`)) return;
    setRemovingId(item.id);
    setListError(null);
    try {
      await apiRequest(`/local-services/${item.id}`, { method: 'DELETE', token });
      if (selectedId === item.id) setSelectedId(null);
      await loadList();
    } catch (err) {
      setListError(err instanceof Error ? err.message : 'Failed to remove service');
    } finally {
      setRemovingId(null);
    }
  }

  async function addContact(event: FormEvent) {
    event.preventDefault();
    if (!selected) return;
    setSavingContact(true);
    setContactError(null);
    try {
      await apiRequest(`/local-services/${selected.id}/contacts`, {
        method: 'POST',
        token,
        body: { name: contactName.trim(), phone: contactPhone.trim() },
      });
      setContactName('');
      setContactPhone('');
      await loadList();
    } catch (err) {
      setContactError(err instanceof Error ? err.message : 'Failed to add number');
    } finally {
      setSavingContact(false);
    }
  }

  async function removeContact(contact: LocalContact) {
    if (!selected) return;
    if (!window.confirm(`Remove “${contact.name}” (${contact.phone}) from ${selected.name}?`)) {
      return;
    }
    setRemovingContactId(contact.id);
    setContactError(null);
    try {
      await apiRequest(`/local-services/${selected.id}/contacts/${contact.id}`, {
        method: 'DELETE',
        token,
      });
      await loadList();
    } catch (err) {
      setContactError(err instanceof Error ? err.message : 'Failed to remove number');
    } finally {
      setRemovingContactId(null);
    }
  }

  return (
    <div className="space-y-6">
      <PageHeader
        title="Find services"
        subtitle="Trades shown on the kiosk Find Services screen, with the names and phone numbers inside each one."
      />

      <Panel title="Add a service">
        <form onSubmit={(event) => void addService(event)}>
          <div className="settings-row">
            <label>
              Service name
              <Input
                value={serviceName}
                onChange={(event) => setServiceName(event.target.value)}
                placeholder="Laundry"
                required
              />
            </label>
          </div>
          {formError ? <p className="error">{formError}</p> : null}
          <div className="mt-3">
            <Button type="submit" disabled={savingService}>
              {savingService ? 'Adding…' : 'Add service'}
            </Button>
          </div>
        </form>
      </Panel>

      <div className="grid gap-6 lg:grid-cols-2">
        <Panel title="Services on kiosks">
          {listError ? <p className="error">{listError}</p> : null}
          {loading && !list ? <p>Loading…</p> : null}
          {!loading && list && list.categories.length === 0 ? (
            <EmptyState title="No services" description="Add a trade above." />
          ) : null}
          {list && list.categories.length > 0 ? (
            <table className="table">
              <thead>
                <tr>
                  <th>Service</th>
                  <th>Numbers</th>
                  <th />
                </tr>
              </thead>
              <tbody>
                {list.categories.map((item) => (
                  <tr key={item.id} className={item.id === selectedId ? 'bg-muted/40' : undefined}>
                    <td className="font-medium">{item.name}</td>
                    <td>{item.contacts.length}</td>
                    <td className="whitespace-nowrap">
                      <Button
                        type="button"
                        variant="ghost"
                        onClick={() => {
                          setSelectedId(item.id);
                          setContactError(null);
                        }}
                      >
                        Numbers
                      </Button>
                      <Button
                        type="button"
                        variant="ghost"
                        onClick={() => void removeService(item)}
                        disabled={removingId === item.id}
                      >
                        {removingId === item.id ? 'Removing…' : 'Remove'}
                      </Button>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          ) : null}
        </Panel>

        <Panel title={selected ? `${selected.name} numbers` : 'Numbers'}>
          {selected ? (
            <>
              <form onSubmit={(event) => void addContact(event)}>
                <div className="settings-row">
                  <label>
                    Name
                    <Input
                      value={contactName}
                      onChange={(event) => setContactName(event.target.value)}
                      placeholder="Ravi Sharma"
                      required
                    />
                  </label>
                  <label>
                    Phone
                    <Input
                      value={contactPhone}
                      onChange={(event) => setContactPhone(event.target.value)}
                      placeholder="9876543210"
                      inputMode="numeric"
                      pattern="[0-9]{10}"
                      required
                    />
                  </label>
                </div>
                {contactError ? <p className="error">{contactError}</p> : null}
                <div className="mt-3">
                  <Button type="submit" disabled={savingContact}>
                    {savingContact ? 'Adding…' : 'Add number'}
                  </Button>
                </div>
              </form>
              {selected.contacts.length === 0 ? (
                <div className="mt-4">
                  <EmptyState
                    title="No numbers yet"
                    description="Add a name and a 10-digit mobile number."
                  />
                </div>
              ) : (
                <table className="table mt-4">
                  <thead>
                    <tr>
                      <th>Name</th>
                      <th>Phone</th>
                      <th />
                    </tr>
                  </thead>
                  <tbody>
                    {selected.contacts.map((contact) => (
                      <tr key={contact.id}>
                        <td className="font-medium">{contact.name}</td>
                        <td className="font-mono text-sm">{contact.phone}</td>
                        <td>
                          <Button
                            type="button"
                            variant="ghost"
                            onClick={() => void removeContact(contact)}
                            disabled={removingContactId === contact.id}
                          >
                            {removingContactId === contact.id ? 'Removing…' : 'Remove'}
                          </Button>
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              )}
            </>
          ) : (
            <EmptyState title="Select a service" description="Choose Numbers on a service to edit its list." />
          )}
        </Panel>
      </div>
    </div>
  );
}
