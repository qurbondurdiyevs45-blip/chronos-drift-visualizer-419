import { EventEmitter } from 'events';

export interface TimingPacket {
  nodeId: string;
  clientSentAt: number;     // T1: Client timestamp on send
  serverReceivedAt: number; // T2: Server timestamp on receipt
  serverSentAt: number;     // T3: Server timestamp on reply
  clientReceivedAt: number; // T4: Client timestamp on final receipt
}

export interface DriftMetrics {
  nodeId: string;
  roundTripTime: number;
  clockOffset: number;
  jitter: number;
  lastUpdate: number;
  sampleCount: number;
}

export class DriftCalculator extends EventEmitter {
  private nodeStats: Map<string, DriftMetrics> = new Map();
  private readonly historyLimit = 50;
  private history: Map<string, number[]> = new Map();

  /**
   * Processes a timing packet using the Network Time Protocol (NTP) algorithm.
   * Round Trip Time (RTT) = (T4 - T1) - (T3 - T2)
   * Clock Offset (theta) = ((T2 - T1) + (T3 - T4)) / 2
   */
  public calculate(packet: TimingPacket): DriftMetrics {
    const { nodeId, clientSentAt, serverReceivedAt, serverSentAt, clientReceivedAt } = packet;

    const rtt = (clientReceivedAt - clientSentAt) - (serverSentAt - serverReceivedAt);
    const offset = ((serverReceivedAt - clientSentAt) + (serverSentAt - clientReceivedAt)) / 2;

    const previousMetrics = this.nodeStats.get(nodeId);
    const jitter = previousMetrics 
      ? Math.abs(offset - previousMetrics.clockOffset) 
      : 0;

    const metrics: DriftMetrics = {
      nodeId,
      roundTripTime: rtt,
      clockOffset: offset,
      jitter,
      lastUpdate: Date.now(),
      sampleCount: (previousMetrics?.sampleCount || 0) + 1
    };

    this.nodeStats.set(nodeId, metrics);
    this.updateHistory(nodeId, offset);
    
    this.emit('metricsUpdated', metrics);
    return metrics;
  }

  /**
   * Stores historical offsets to calculate moving averages or stability.
   */
  private updateHistory(nodeId: string, offset: number): void {
    if (!this.history.has(nodeId)) {
      this.history.set(nodeId, []);
    }
    const nodeHistory = this.history.get(nodeId)!;
    nodeHistory.push(offset);
    
    if (nodeHistory.length > this.historyLimit) {
      nodeHistory.shift();
    }
  }

  /**
   * Returns a summary of all active node drifts for visualization.
   */
  public getAllMetrics(): DriftMetrics[] {
    return Array.from(this.nodeStats.values());
  }

  /**
   * Calculates the standard deviation of the last 50 samples for a node.
   * Higher values indicate clock instability or network congestion.
   */
  public getStability(nodeId: string): number {
    const offsets = this.history.get(nodeId) || [];
    if (offsets.length < 2) return 0;

    const mean = offsets.reduce((a, b) => a + b, 0) / offsets.length;
    const variance = offsets.reduce((a, b) => a + Math.pow(b - mean, 2), 0) / offsets.length;
    return Math.sqrt(variance);
  }

  /**
   * Removes a node from the registry when a WebSocket disconnects.
   */
  public removeNode(nodeId: string): void {
    this.nodeStats.delete(nodeId);
    this.history.delete(nodeId);
    this.emit('nodeRemoved', nodeId);
  }
}