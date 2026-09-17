import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "NexoCargo | Gestión de paquetería",
  description: "Plataforma administrativa para agencias de envíos",
};

export default function RootLayout({ children }: Readonly<{ children: React.ReactNode }>) {
  return (
    <html lang="es">
      <body>{children}</body>
    </html>
  );
}
