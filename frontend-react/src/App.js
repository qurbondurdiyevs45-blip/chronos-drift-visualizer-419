import React, { useState, useEffect, useMemo } from 'react';
import { LineChart, Line, XAxis, YAxis, CartesianGrid, Tooltip, Legend, ResponsiveContainer } from 'recharts';
import { Activity, Clock, Server, AlertTriangle, ShieldCheck } from 'lucide-react';

const App = () => {
  const [nodes, setNodes] = useState([]);
  const [driftData, setDriftData] = useState([]);
  const [isLive, setIsLive] = useState(false);
  const [selectedNode, setSelectedNode] = useState(null);

  // Mock data generator for visualization purposes
  useEffect(() => {
    const initialNodes = [
      { id: 'node-01', name: 'US-East-Primary', ip: '192.168.1.10', status: 'online', drift: 0.12 },
      { id: 'node-02', name: 'EU-West-Relay', ip: '10.0.4.55', status: 'online', drift: -0.45 },
      { id: 'node-03', name: 'AP-South-Edge', ip: '172.16.0.12', status: 'warning', drift: 1.82 },
    ];
    setNodes(initialNodes);

    if (isLive) {
      const interval = setInterval(() => {
        const timestamp = new Date().toLocaleTimeString();
        setDriftData(prev => {
          const newData = [...prev, {
            time: timestamp,
            'US-East-Primary': (Math.random() * 0.5 + 0.1).toFixed(3),
            'EU-West-Relay': (Math.random() * 0.8 - 0.4).toFixed(3),
            'AP-South-Edge': (Math.random() * 2.5 + 1.2).toFixed(3),
          }].slice(-20);
          return newData;
        });
      }, 1000);
      return () => clearInterval(interval);
    }
  }, [isLive]);

  const maxDrift = useMemo(() => {
    if (nodes.length === 0) return 0;
    return Math.max(...nodes.map(n => Math.abs(n.drift)));
  }, [nodes]);

  return (
    <div className="min-h-screen bg-slate-900 text-slate-100 font-sans p-6">
      <header className="flex justify-between items-center mb-10 border-b border-slate-700 pb-4">
        <div>
          <h1 className="text-3xl font-bold bg-gradient-to-r from-cyan-400 to-blue-500 bg-clip-text text-transparent">
            Chronos Drift Visualizer
          </h1>
          <p className="text-slate-400 text-sm italic">High-frequency distributed clock forensic suite</p>
        </div>
        <div className="flex gap-4">
          <button 
            onClick={() => setIsLive(!isLive)}
            className={`px-4 py-2 rounded-md font-semibold transition-colors flex items-center gap-2 ${isLive ? 'bg-red-600 hover:bg-red-700' : 'bg-emerald-600 hover:bg-emerald-700'}`}
          >
            <Activity size={18} />
            {isLive ? 'Stop Monitoring' : 'Start Real-time Capture'}
          </button>
        </div>
      </header>

      <main className="grid grid-cols-1 lg:grid-cols-3 gap-6">
        {/* Node Configuration & Health */}
        <section className="lg:col-span-1 space-y-4">
          <h2 className="text-xl font-semibold flex items-center gap-2 text-cyan-300">
            <Server size={20} /> Managed Nodes
          </h2>
          {nodes.map(node => (
            <div 
              key={node.id}
              onClick={() => setSelectedNode(node)}
              className={`p-4 rounded-lg border cursor-pointer transition-all ${selectedNode?.id === node.id ? 'border-cyan-500 bg-slate-800 shadow-[0_0_15px_rgba(6,182,212,0.2)]' : 'border-slate-700 bg-slate-800/50 hover:border-slate-500'}`}
            >
              <div className="flex justify-between items-start">
                <div>
                  <h3 className="font-bold">{node.name}</h3>
                  <code className="text-xs text-slate-400">{node.ip}</code>
                </div>
                {Math.abs(node.drift) > 1.0 ? <AlertTriangle className="text-amber-500" /> : <ShieldCheck className="text-emerald-500" />}
              </div>
              <div className="mt-3 flex items-center justify-between">
                <span className="text-xs uppercase tracking-wider text-slate-500">Current Drift</span>
                <span className={`font-mono text-lg ${Math.abs(node.drift) > 1.0 ? 'text-amber-400' : 'text-emerald-400'}`}>
                  {node.drift > 0 ? '+' : ''}{node.drift}ms
                </span>
              </div>
            </div>
          ))}
        </section>

        {/* Temporal Visualization Area */}
        <section className="lg:col-span-2 bg-slate-800/40 rounded-xl p-6 border border-slate-700">
          <div className="flex justify-between mb-6">
            <h2 className="text-xl font-semibold flex items-center gap-2 text-blue-400">
              <Clock size={20} /> Drift Analysis Lineage
            </h2>
            <div className="text-sm text-slate-400">
              Resolution: <span className="text-white font-mono">0.001ms</span>
            </div>
          </div>

          <div className="h-[400px] w-full">
            <ResponsiveContainer width="100%" height="100%">
              <LineChart data={driftData}>
                <CartesianGrid strokeDasharray="3 3" stroke="#334155" />
                <XAxis dataKey="time" stroke="#94a3b8" fontSize={12} />
                <YAxis stroke="#94a3b8" fontSize={12} unit="ms" />
                <Tooltip 
                  contentStyle={{ backgroundColor: '#1e293b', borderColor: '#334155', color: '#f1f5f9' }}
                  itemStyle={{ fontSize: '12px' }}
                />
                <Legend />
                <Line type="monotone" dataKey="US-East-Primary" stroke="#22d3ee" strokeWidth={2} dot={false} isAnimationActive={false} />
                <Line type="monotone" dataKey="EU-West-Relay" stroke="#818cf8" strokeWidth={2} dot={false} isAnimationActive={false} />
                <Line type="monotone" dataKey="AP-South-Edge" stroke="#fbbf24" strokeWidth={2} dot={false} isAnimationActive={false} />
              </LineChart>
            </ResponsiveContainer>
          </div>

          <div className="mt-6 grid grid-cols-3 gap-4 border-t border-slate-700 pt-6 text-center">
            <div>
              <p className="text-slate-500 text-xs">GLOBAL JITTER</p>
              <p className="text-xl font-mono">0.022ms</p>
            </div>
            <div>
              <p className="text-slate-500 text-xs">PEAK SKEW</p>
              <p className="text-xl font-mono text-amber-400">{maxDrift}ms</p>
            </div>
            <div>
              <p className="text-slate-500 text-xs">SYNC CONFIDENCE</p>
              <p className="text-xl font-mono text-emerald-400">99.98%</p>
            </div>
          </div>
        </section>
      </main>

      <footer className="mt-12 text-center text-slate-600 text-xs">
        Chronos Drift Visualizer — Localized Forensic Clock Analysis — v1.0.4-stable
      </footer>
    </div>
  );
};

export default App;