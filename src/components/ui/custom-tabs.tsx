'use client';

import * as React from 'react';

interface TabsContextValue {
  value: string;
  onValueChange: (value: string) => void;
}

const TabsContext = React.createContext<TabsContextValue | undefined>(undefined);

export function Tabs({ 
  value, 
  onValueChange, 
  children, 
  className = "" 
}: { 
  value: string; 
  onValueChange: (value: string) => void; 
  children: React.ReactNode;
  className?: string;
}) {
  return (
    <TabsContext.Provider value={{ value, onValueChange }}>
      <div className={className}>
        {children}
      </div>
    </TabsContext.Provider>
  );
}

export function TabsList({ 
  children, 
  className = "" 
}: { 
  children: React.ReactNode;
  className?: string;
}) {
  return (
    <div className={`ps-tab-list ps-animate-fade-in ${className}`}>
      {children}
    </div>
  );
}

export function TabsTrigger({ 
  value, 
  children 
}: { 
  value: string; 
  children: React.ReactNode;
}) {
  const context = React.useContext(TabsContext);
  if (!context) throw new Error('TabsTrigger must be used within Tabs');
  
  const isActive = context.value === value;
  
  return (
    <button
      onClick={() => context.onValueChange(value)}
      className={`
        ps-tab-trigger transition-smooth transform-gpu
        ${isActive 
          ? 'ps-tab-trigger-active ps-animate-scale-in' 
          : 'ps-tab-trigger-inactive'
        }
      `}
    >
      {children}
    </button>
  );
}

export function TabsContent({ 
  value, 
  children,
  className = ""
}: { 
  value: string; 
  children: React.ReactNode;
  className?: string;
}) {
  const context = React.useContext(TabsContext);
  if (!context) throw new Error('TabsContent must be used within Tabs');
  
  if (context.value !== value) return null;
  
  return (
    <div className={`mt-8 ps-animate-fade-in ${className}`}>
      {children}
    </div>
  );
}