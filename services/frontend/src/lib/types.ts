// Shared TypeScript types for PollFlow frontend
// Matches existing database schema (2-option polls with IP-based voting)

export interface Poll {
  id: number;
  title: string;
  description: string | null;
  optionA: string;
  optionB: string;
  pollCategory: string;
  startTime: string; // ISO 8601
  endTime: string; // ISO 8601
  status: "pending" | "active" | "closed";
  createdAt: string; // ISO 8601
  voteCountA: number;
  voteCountB: number;
  totalVotes: number;
}

export interface VoteRequest {
  pollId: number;
  option: "a" | "b";
  userIp: string;
}

export interface VoteResponse {
  success: boolean;
  message?: string;
}

export interface PollResults {
  pollId: number;
  voteCountA: number;
  voteCountB: number;
  totalVotes: number;
  lastUpdated: string; // ISO 8601
}
