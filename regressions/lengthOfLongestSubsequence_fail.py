from typing import List

def lengthOfLongestSubsequence(nums: List[int], target: int) -> int:
    dp=[-1]*(target+1)
    dp[0]=0
    for a in nums:
        for i in range(target-a,-1,-1):
            if dp[i]==-1:continue
            dp[i+a]=max(dp[i+a],dp[i]+1)
    return dp[-1]

assert lengthOfLongestSubsequence([1, 2, 3], 3) == 3
