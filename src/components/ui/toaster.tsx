'use client';

import React from 'react';

export function Toaster() {
  return null; // Simple placeholder for now
}

export function useToast() {
  return {
    toast: (message: any) => console.log('Toast:', message)
  };
}