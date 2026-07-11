import { createBrowserRouter } from 'react-router'
import { RootLayout } from '@/app/RootLayout'
import { ProtectedRoute } from '@/app/ProtectedRoute'
import { LoginPage } from '@/features/auth/LoginPage'
import { HabitsPage } from '@/features/habits/HabitsPage'

export const router = createBrowserRouter([
  {
    path: '/',
    element: <RootLayout />,
    children: [
      { path: 'login', element: <LoginPage /> },
      {
        element: <ProtectedRoute />,
        children: [{ index: true, element: <HabitsPage /> }],
      },
    ],
  },
])
