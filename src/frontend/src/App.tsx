import { useEffect, useState } from 'react'
import type { FormEvent } from 'react'
import './App.css'

const apiBaseUrl = import.meta.env.VITE_API_BASE_URL ?? 'http://localhost:5240'

type SiteContent = {
  home: string
  comeFunziona: string
  abbonamento: string
  chiSiamo: string
  contatti: {
    telefono: string
    email: string
    sede: string
  }
}

type AuthResponse = {
  userId: string
  fullName: string
  email: string
  role: 'Customer' | 'Admin'
  token: string
}

type MeResponse = {
  id: string
  fullName: string
  email: string
  role: 'Customer' | 'Admin'
  subscriptionActive: boolean
  subscriptionExpiresAtUtc: string | null
}

type HouseRequest = {
  id: string
  region: string
  province: string
  cityOrArea: string
  budgetMin: number
  budgetMax: number
  propertyType: string
  status: string
  createdAt: string
}

type AdminUser = {
  id: string
  fullName: string
  email: string
  role: string
  subscriptionActive: boolean
  subscriptionExpiresAtUtc: string | null
}

type AdminRequest = {
  id: string
  customerName: string
  customerEmail: string
  region: string
  province: string
  cityOrArea: string
  budgetMin: number
  budgetMax: number
  propertyType: string
  status: string
}

const emptyNewRequest = {
  region: '',
  province: '',
  cityOrArea: '',
  budgetMin: 50000,
  budgetMax: 200000,
  propertyType: 'appartamento',
  propertyCondition: 'nuova',
  squareMeters: 80,
  bedrooms: 2,
  bathrooms: 1,
  hasGarden: false,
  hasGarage: false,
  hasTerrace: false,
  hasPool: false,
  hasCellar: false,
  energyClass: 'A',
  style: 'moderno',
  finishingLevel: 'medio',
  desiredTimeline: '12 mesi',
  notes: '',
  attachmentUrl: '',
}

async function apiFetch<T>(path: string, options: RequestInit = {}, token?: string) {
  const headers = new Headers(options.headers)
  headers.set('Content-Type', 'application/json')

  if (token) {
    headers.set('Authorization', `Bearer ${token}`)
  }

  const response = await fetch(`${apiBaseUrl}${path}`, {
    ...options,
    headers,
  })

  if (!response.ok) {
    let message = `Errore ${response.status}`
    try {
      const payload = await response.json()
      message = payload.message ?? message
    } catch {
      // no-op
    }
    throw new Error(message)
  }

  if (response.status === 204) {
    return undefined as T
  }

  return (await response.json()) as T
}

function App() {
  const [siteContent, setSiteContent] = useState<SiteContent | null>(null)
  const [token, setToken] = useState(localStorage.getItem('emcasa_token') ?? '')
  const [role, setRole] = useState<'Customer' | 'Admin' | ''>((localStorage.getItem('emcasa_role') as 'Customer' | 'Admin') ?? '')
  const [message, setMessage] = useState('')
  const [me, setMe] = useState<MeResponse | null>(null)

  const [registerForm, setRegisterForm] = useState({
    fullName: '',
    email: '',
    password: '',
    privacyConsent: false,
  })

  const [loginForm, setLoginForm] = useState({
    email: '',
    password: '',
  })

  const [newRequest, setNewRequest] = useState(emptyNewRequest)
  const [myRequests, setMyRequests] = useState<HouseRequest[]>([])
  const [adminUsers, setAdminUsers] = useState<AdminUser[]>([])
  const [adminRequests, setAdminRequests] = useState<AdminRequest[]>([])

  useEffect(() => {
    apiFetch<SiteContent>('/api/public/site-content')
      .then(setSiteContent)
      .catch(() => setMessage('Impossibile caricare i contenuti pubblici.'))
  }, [])

  useEffect(() => {
    if (!token) {
      setMe(null)
      return
    }

    apiFetch<MeResponse>('/api/me', {}, token)
      .then(setMe)
      .catch(() => {
        localStorage.removeItem('emcasa_token')
        localStorage.removeItem('emcasa_role')
        setToken('')
        setRole('')
      })
  }, [token])

  useEffect(() => {
    if (!token || role !== 'Customer') {
      return
    }

    apiFetch<HouseRequest[]>('/api/house-requests/me', {}, token)
      .then(setMyRequests)
      .catch((error: Error) => setMessage(error.message))
  }, [token, role])

  useEffect(() => {
    if (!token || role !== 'Admin') {
      return
    }

    Promise.all([
      apiFetch<AdminUser[]>('/api/admin/users', {}, token),
      apiFetch<AdminRequest[]>('/api/admin/house-requests', {}, token),
    ])
      .then(([users, requests]) => {
        setAdminUsers(users)
        setAdminRequests(requests)
      })
      .catch((error: Error) => setMessage(error.message))
  }, [token, role])

  async function handleRegister(event: FormEvent) {
    event.preventDefault()
    setMessage('')

    try {
      const response = await apiFetch<AuthResponse>('/api/auth/register', {
        method: 'POST',
        body: JSON.stringify(registerForm),
      })

      localStorage.setItem('emcasa_token', response.token)
      localStorage.setItem('emcasa_role', response.role)
      setToken(response.token)
      setRole(response.role)
      setMessage('Registrazione completata.')
    } catch (error) {
      setMessage((error as Error).message)
    }
  }

  async function handleLogin(event: FormEvent) {
    event.preventDefault()
    setMessage('')

    try {
      const response = await apiFetch<AuthResponse>('/api/auth/login', {
        method: 'POST',
        body: JSON.stringify(loginForm),
      })

      localStorage.setItem('emcasa_token', response.token)
      localStorage.setItem('emcasa_role', response.role)
      setToken(response.token)
      setRole(response.role)
      setMessage('Accesso effettuato.')
    } catch (error) {
      setMessage((error as Error).message)
    }
  }

  async function activateSubscription() {
    try {
      await apiFetch('/api/subscription/activate', { method: 'POST' }, token)
      const currentMe = await apiFetch<MeResponse>('/api/me', {}, token)
      setMe(currentMe)
      setMessage('Abbonamento annuale attivato.')
    } catch (error) {
      setMessage((error as Error).message)
    }
  }

  async function submitHouseRequest(event: FormEvent) {
    event.preventDefault()
    setMessage('')

    try {
      await apiFetch('/api/house-requests', { method: 'POST', body: JSON.stringify(newRequest) }, token)
      const requests = await apiFetch<HouseRequest[]>('/api/house-requests/me', {}, token)
      setMyRequests(requests)
      setNewRequest(emptyNewRequest)
      setMessage('Richiesta inviata con successo.')
    } catch (error) {
      setMessage((error as Error).message)
    }
  }

  async function updateRequestStatus(requestId: string, status: string) {
    try {
      await apiFetch(`/api/admin/house-requests/${requestId}/status`, {
        method: 'PATCH',
        body: JSON.stringify({ status }),
      }, token)

      const requests = await apiFetch<AdminRequest[]>('/api/admin/house-requests', {}, token)
      setAdminRequests(requests)
      setMessage('Stato pratica aggiornato.')
    } catch (error) {
      setMessage((error as Error).message)
    }
  }

  function logout() {
    localStorage.removeItem('emcasa_token')
    localStorage.removeItem('emcasa_role')
    setToken('')
    setRole('')
    setMe(null)
    setMessage('Sessione terminata.')
  }

  function renderRequestStatus(status: string) {
    const value = status.toLowerCase()
    if (value.includes('closed')) return { label: 'Chiusa', className: 'status closed' }
    if (value.includes('proposal')) return { label: 'Proposta inviata', className: 'status progress' }
    if (value.includes('analysis') || value.includes('charge') || value.includes('appointment')) {
      return { label: 'In lavorazione', className: 'status progress' }
    }

    return { label: 'Nuova', className: 'status new' }
  }

  function goToSection(id: string) {
    const section = document.getElementById(id)
    if (section) {
      section.scrollIntoView({ behavior: 'smooth', block: 'start' })
    }
  }

  const guestSections = [
    { id: 'login-section', label: 'Login' },
    { id: 'register-section', label: 'Registrazione' },
  ]

  const customerSections = [
    { id: 'customer-profile', label: 'Profilo' },
    { id: 'customer-request', label: 'Nuova richiesta' },
    { id: 'customer-practices', label: 'Le mie pratiche' },
  ]

  const adminSections = [
    { id: 'admin-users', label: 'Utenti' },
    { id: 'admin-practices', label: 'Pratiche clienti' },
  ]

  const sections = !token
    ? guestSections
    : role === 'Customer'
      ? customerSections
      : adminSections

  return (
    <main className="app-page">
      <header className="site-header">
        <div className="site-header-inner">
          <button className="brand" onClick={() => goToSection('top')}>
            <img className="brand-logo" src="/logo-emcasa.jpg" alt="Logo E&M Casa" />
            <div className="brand-text">
              <p className="brand-kicker">E&M Casa Personalizzata</p>
              <strong>Web App Immobiliare</strong>
            </div>
          </button>

          <nav className="site-nav" aria-label="Sezioni disponibili">
            {sections.map((section) => (
              <button key={section.id} className="site-nav-link" onClick={() => goToSection(section.id)}>
                {section.label}
              </button>
            ))}
          </nav>

          <div className="site-header-actions">
            <span className="tag">API: {apiBaseUrl}</span>
            {token ? (
              <button className="button ghost" onClick={logout}>Logout</button>
            ) : null}
          </div>
        </div>
      </header>

      <section className="hero" id="top">
        <p className="hero-kicker">INSIEME COSTRUIAMO IL TUO SOGNO</p>
        <h1>{siteContent?.home ?? 'E&M Casa Personalizzata'}</h1>
        <p>{siteContent?.comeFunziona ?? 'Registrati, attiva abbonamento, crea richiesta e segui gli aggiornamenti.'}</p>
        {siteContent ? (
          <div className="hero-meta">
            <span><strong>Abbonamento:</strong> {siteContent.abbonamento}</span>
            <span><strong>Chi siamo:</strong> {siteContent.chiSiamo}</span>
          </div>
        ) : null}
      </section>

      {!token ? (
        <>
          <section className="section" id="login-section">
            <h2>Login</h2>
            <p className="muted">Accedi con il tuo account cliente o admin.</p>
            <form className="form-grid" onSubmit={handleLogin}>
              <input
                placeholder="Email"
                type="email"
                value={loginForm.email}
                onChange={(event) => setLoginForm({ ...loginForm, email: event.target.value })}
              />
              <input
                placeholder="Password"
                type="password"
                value={loginForm.password}
                onChange={(event) => setLoginForm({ ...loginForm, password: event.target.value })}
              />
              <button className="button" type="submit">Accedi</button>
            </form>
          </section>

          <section className="section" id="register-section">
            <h2>Registrazione cliente</h2>
            <p className="muted">Crea l’account per accedere all’area cliente e inviare richieste.</p>
            <form className="form-grid" onSubmit={handleRegister}>
              <input
                placeholder="Nome e cognome"
                value={registerForm.fullName}
                onChange={(event) => setRegisterForm({ ...registerForm, fullName: event.target.value })}
              />
              <input
                placeholder="Email"
                type="email"
                value={registerForm.email}
                onChange={(event) => setRegisterForm({ ...registerForm, email: event.target.value })}
              />
              <input
                placeholder="Password"
                type="password"
                value={registerForm.password}
                onChange={(event) => setRegisterForm({ ...registerForm, password: event.target.value })}
              />
              <label className="checkbox">
                <input
                  type="checkbox"
                  checked={registerForm.privacyConsent}
                  onChange={(event) => setRegisterForm({ ...registerForm, privacyConsent: event.target.checked })}
                />
                Consenso privacy
              </label>
              <button className="button" type="submit">Registrati</button>
            </form>
          </section>
        </>
      ) : null}

      {token && role === 'Customer' ? (
        <>
          <section className="section" id="customer-profile">
            <h2>Profilo cliente</h2>
            {me ? (
              <>
                <p><strong>Utente:</strong> {me.fullName} ({me.email})</p>
                <p>
                  <strong>Abbonamento:</strong>{' '}
                  <span className={me.subscriptionActive ? 'status active' : 'status inactive'}>
                    {me.subscriptionActive ? `Attivo fino al ${new Date(me.subscriptionExpiresAtUtc ?? '').toLocaleDateString()}` : 'Non attivo'}
                  </span>
                </p>
              </>
            ) : null}
            <button className="button" onClick={activateSubscription}>Attiva abbonamento annuale</button>
          </section>

          <section className="section" id="customer-request">
            <h2>Nuova richiesta casa</h2>
            <p className="muted">Compila i campi principali e invia la pratica.</p>
            <form className="form-grid two-columns" onSubmit={submitHouseRequest}>
              <input placeholder="Regione" value={newRequest.region} onChange={(event) => setNewRequest({ ...newRequest, region: event.target.value })} />
              <input placeholder="Provincia" value={newRequest.province} onChange={(event) => setNewRequest({ ...newRequest, province: event.target.value })} />
              <input placeholder="Comune / Zona" value={newRequest.cityOrArea} onChange={(event) => setNewRequest({ ...newRequest, cityOrArea: event.target.value })} />
              <input placeholder="Tipologia immobile" value={newRequest.propertyType} onChange={(event) => setNewRequest({ ...newRequest, propertyType: event.target.value })} />
              <input type="number" placeholder="Budget Min" value={newRequest.budgetMin} onChange={(event) => setNewRequest({ ...newRequest, budgetMin: Number(event.target.value) })} />
              <input type="number" placeholder="Budget Max" value={newRequest.budgetMax} onChange={(event) => setNewRequest({ ...newRequest, budgetMax: Number(event.target.value) })} />
              <input type="number" placeholder="Mq" value={newRequest.squareMeters} onChange={(event) => setNewRequest({ ...newRequest, squareMeters: Number(event.target.value) })} />
              <input type="number" placeholder="Camere" value={newRequest.bedrooms} onChange={(event) => setNewRequest({ ...newRequest, bedrooms: Number(event.target.value) })} />
              <input type="number" placeholder="Bagni" value={newRequest.bathrooms} onChange={(event) => setNewRequest({ ...newRequest, bathrooms: Number(event.target.value) })} />
              <input placeholder="Classe energetica" value={newRequest.energyClass} onChange={(event) => setNewRequest({ ...newRequest, energyClass: event.target.value })} />
              <input placeholder="Stile" value={newRequest.style} onChange={(event) => setNewRequest({ ...newRequest, style: event.target.value })} />
              <input placeholder="Livello finiture" value={newRequest.finishingLevel} onChange={(event) => setNewRequest({ ...newRequest, finishingLevel: event.target.value })} />
              <textarea
                className="full"
                placeholder="Note aggiuntive"
                value={newRequest.notes}
                onChange={(event) => setNewRequest({ ...newRequest, notes: event.target.value })}
              />
              <button className="button" type="submit">Invia richiesta</button>
            </form>
          </section>

          <section className="section" id="customer-practices">
            <h2>Le mie pratiche</h2>
            <ul className="request-list">
              {myRequests.map((item) => (
                <li key={item.id} className="request-item">
                  <div>
                    <strong>{item.region} - {item.cityOrArea}</strong>
                    <p className="muted">{item.propertyType} · Budget €{item.budgetMin} - €{item.budgetMax}</p>
                  </div>
                  <span className={renderRequestStatus(item.status).className}>{renderRequestStatus(item.status).label}</span>
                </li>
              ))}
              {myRequests.length === 0 ? <li>Nessuna richiesta inviata.</li> : null}
            </ul>
          </section>
        </>
      ) : null}

      {token && role === 'Admin' ? (
        <>
          <section className="section" id="admin-users">
            <h2>Utenti registrati</h2>
            <ul>
              {adminUsers.map((user) => (
                <li key={user.id}>{user.fullName} · {user.email} · {user.role}</li>
              ))}
            </ul>
          </section>

          <section className="section" id="admin-practices">
            <h2>Pratiche clienti</h2>
            <ul>
              {adminRequests.map((item) => (
                <li key={item.id} className="admin-row">
                  <span>
                    <strong>{item.customerName}</strong> · {item.region}/{item.cityOrArea} · {item.propertyType}
                  </span>
                  <select value={item.status} onChange={(event) => updateRequestStatus(item.id, event.target.value)}>
                    <option value="Submitted">Submitted</option>
                    <option value="InAnalysis">InAnalysis</option>
                    <option value="InCharge">InCharge</option>
                    <option value="ProposalSent">ProposalSent</option>
                    <option value="AppointmentScheduled">AppointmentScheduled</option>
                    <option value="Closed">Closed</option>
                  </select>
                </li>
              ))}
              {adminRequests.length === 0 ? <li>Nessuna pratica disponibile.</li> : null}
            </ul>
          </section>
        </>
      ) : null}

      {message ? <p className="message">{message}</p> : null}

      {siteContent ? (
        <footer className="footer">
          <p className="brand-kicker">CONTATTI</p>
          <h2>Parla con E&M Casa</h2>
          <p><strong>Telefono:</strong> {siteContent.contatti.telefono}</p>
          <p><strong>Email:</strong> {siteContent.contatti.email}</p>
          <p><strong>Sede:</strong> {siteContent.contatti.sede}</p>
        </footer>
      ) : null}
    </main>
  )
}

export default App
