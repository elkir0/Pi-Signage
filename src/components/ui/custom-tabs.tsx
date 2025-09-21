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
    <div className={`flex flex-wrap gap-2 p-2 bg-gray-900 border-2 border-red-600 rounded-lg ${className}`}>
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
        flex items-center justify-center px-4 py-2 rounded transition-all font-medium text-sm
        ${isActive 
          ? 'bg-red-600 text-white shadow-lg shadow-red-600/50' 
          : 'bg-gray-800 text-gray-400 hover:bg-gray-700 hover:text-white border border-gray-700'
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
    <div className={`mt-6 animate-fade-in ${className}`}>
      {children}
    </div>
  );
}