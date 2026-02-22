import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "EKATAN",
  description: "Premium residential interior design and execution ERP",
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en">
      <body>{children}</body>
    </html>
  );
}
