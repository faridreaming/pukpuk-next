import { useState, type FormEvent } from 'react'
import { supabase } from '@/lib/supabase'

export function LoginPage() {
  const [email, setEmail] = useState('')
  const [status, setStatus] = useState<'idle' | 'sending' | 'sent' | 'error'>(
    'idle',
  )

  async function handleSubmit(e: FormEvent) {
    e.preventDefault()
    setStatus('sending')
    const { error } = await supabase.auth.signInWithOtp({
      email,
      options: { emailRedirectTo: window.location.origin },
    })
    setStatus(error ? 'error' : 'sent')
  }

  if (status === 'sent') {
    return <p>Cek email kamu, ada link buat masuk.</p>
  }

  return (
    <form onSubmit={handleSubmit}>
      <input
        type="email"
        value={email}
        onChange={(e) => setEmail(e.target.value)}
        placeholder="email kamu"
        required
      />
      <button type="submit" disabled={status === 'sending'}>
        {status === 'sending' ? 'Mengirim...' : 'Kirim magic link'}
      </button>
      {status === 'error' && <p>Gagal kirim, coba lagi.</p>}
    </form>
  )
}
