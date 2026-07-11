import { Navigate, Outlet } from 'react-router'
import { useSession } from '@/features/auth/useSession'

export function ProtectedRoute() {
  const { session, loading } = useSession()

  if (loading) return <p>Memuat...</p>
  if (!session) return <Navigate to="/login" replace />

  return <Outlet />
}
