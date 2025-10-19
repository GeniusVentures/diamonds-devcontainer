// import { execSync } from 'child_process';

// /**
//  * VaultSecretManager - TypeScript client for HashiCorp Vault operations
//  * Provides secure secret management for Diamonds development environment
//  */
// export class VaultSecretManager {
//   private vaultAddr: string;
//   private vaultToken: string | null = null;
//   private githubToken: string | null = null;
//   private isConnected: boolean = false;

//   constructor(vaultAddr?: string, githubToken?: string) {
//     this.vaultAddr = vaultAddr || process.env.VAULT_ADDR || 'http://vault-dev:8200';
//     this.githubToken = githubToken || process.env.GITHUB_TOKEN || null;
//   }

//   /**
//    * Connect to Vault using GitHub authentication
//    */
//   async connect(): Promise<void> {
//     if (this.isConnected) {
//       return;
//     }

//     if (!this.githubToken) {
//       throw new Error('GitHub token is required for Vault authentication. Set GITHUB_TOKEN environment variable.');
//     }

//     try {
//       console.log('🔐 Authenticating with Vault using GitHub token...');

//       // Use vault CLI for authentication
//       const authCommand = `vault login -method=github token="${this.githubToken}" -format=json`;
//       const result = execSync(authCommand, {
//         encoding: 'utf8',
//         env: {
//           ...process.env,
//           VAULT_ADDR: this.vaultAddr
//         }
//       });

//       const authResponse = JSON.parse(result);
//       this.vaultToken = authResponse.auth?.client_token;

//       if (!this.vaultToken) {
//         throw new Error('Failed to extract Vault token from authentication response');
//       }

//       this.isConnected = true;
//       console.log('✅ Successfully authenticated with Vault');

//     } catch (error) {
//       const errorMessage = error instanceof Error ? error.message : 'Unknown error';
//       throw new Error(`Vault authentication failed: ${errorMessage}`);
//     }
//   }

//   /**
//    * Get a secret from Vault
//    */
//   async getSecret(secretPath: string, secretKey: string): Promise<string> {
//     await this.ensureConnected();

//     try {
//       const command = `vault kv get -field="${secretKey}" "${secretPath}"`;
//       const result = execSync(command, {
//         encoding: 'utf8',
//         env: {
//           ...process.env,
//           VAULT_ADDR: this.vaultAddr,
//           VAULT_TOKEN: this.vaultToken!
//         }
//       });

//       return result.trim();

//     } catch (error) {
//       const errorMessage = error instanceof Error ? error.message : 'Unknown error';
//       throw new Error(`Failed to get secret ${secretPath}:${secretKey}: ${errorMessage}`);
//     }
//   }

//   /**
//    * Set a secret in Vault
//    */
//   async setSecret(secretPath: string, secretKey: string, secretValue: string): Promise<void> {
//     await this.ensureConnected();

//     try {
//       const command = `vault kv put "${secretPath}" "${secretKey}=${secretValue}"`;
//       execSync(command, {
//         encoding: 'utf8',
//         env: {
//           ...process.env,
//           VAULT_ADDR: this.vaultAddr,
//           VAULT_TOKEN: this.vaultToken!
//         }
//       });

//       console.log(`✅ Secret set: ${secretPath}:${secretKey}`);

//     } catch (error) {
//       const errorMessage = error instanceof Error ? error.message : 'Unknown error';
//       throw new Error(`Failed to set secret ${secretPath}:${secretKey}: ${errorMessage}`);
//     }
//   }

//   /**
//    * List secrets in a Vault path
//    */
//   async listSecrets(secretPath: string): Promise<string[]> {
//     await this.ensureConnected();

//     try {
//       const command = `vault kv list "${secretPath}"`;
//       const result = execSync(command, {
//         encoding: 'utf8',
//         env: {
//           ...process.env,
//           VAULT_ADDR: this.vaultAddr,
//           VAULT_TOKEN: this.vaultToken!
//         }
//       });

//       // Parse the output - vault kv list returns one key per line
//       return result.trim().split('\n').filter(key => key.length > 0);

//     } catch (error) {
//       const errorMessage = error instanceof Error ? error.message : 'Unknown error';
//       throw new Error(`Failed to list secrets in ${secretPath}: ${errorMessage}`);
//     }
//   }

//   /**
//    * Batch retrieve multiple secrets
//    */
//   async getSecrets(secrets: Array<{ path: string; key: string }>): Promise<Record<string, string>> {
//     await this.ensureConnected();

//     const result: Record<string, string> = {};

//     for (const secret of secrets) {
//       try {
//         const value = await this.getSecret(secret.path, secret.key);
//         result[`${secret.path}:${secret.key}`] = value;
//       } catch (error) {
//         console.warn(`⚠️  Failed to get secret ${secret.path}:${secret.key}:`, error);
//         // Continue with other secrets
//       }
//     }

//     return result;
//   }

//   /**
//    * Batch set multiple secrets
//    */
//   async setSecrets(secrets: Array<{ path: string; key: string; value: string }>): Promise<void> {
//     await this.ensureConnected();

//     for (const secret of secrets) {
//       await this.setSecret(secret.path, secret.key, secret.value);
//     }
//   }

//   /**
//    * Check if connected to Vault
//    */
//   isConnectedToVault(): boolean {
//     return this.isConnected && !!this.vaultToken;
//   }

//   /**
//    * Get Vault status information
//    */
//   async getStatus(): Promise<{
//     connected: boolean;
//     address: string;
//     authenticated: boolean;
//   }> {
//     try {
//       const command = 'vault status -format=json';
//       const result = execSync(command, {
//         encoding: 'utf8',
//         env: {
//           ...process.env,
//           VAULT_ADDR: this.vaultAddr,
//           VAULT_TOKEN: this.vaultToken || undefined
//         }
//       });

//       const status = JSON.parse(result);

//       return {
//         connected: true,
//         address: this.vaultAddr,
//         authenticated: status.initialized && status.sealed === false
//       };

//     } catch (error) {
//       return {
//         connected: false,
//         address: this.vaultAddr,
//         authenticated: false
//       };
//     }
//   }

//   /**
//    * Refresh authentication token
//    */
//   async refreshAuth(): Promise<void> {
//     console.log('🔄 Refreshing Vault authentication...');
//     this.isConnected = false;
//     this.vaultToken = null;
//     await this.connect();
//   }

//   /**
//    * Ensure connection to Vault
//    */
//   private async ensureConnected(): Promise<void> {
//     if (!this.isConnected) {
//       await this.connect();
//     }

//     if (!this.vaultToken) {
//       throw new Error('Not authenticated with Vault');
//     }
//   }

//   /**
//    * Clean up resources
//    */
//   async disconnect(): Promise<void> {
//     this.vaultToken = null;
//     this.isConnected = false;
//     console.log('👋 Disconnected from Vault');
//   }
// }

// /**
//  * Singleton instance for easy access
//  */
// let vaultManagerInstance: VaultSecretManager | null = null;

// export function getVaultManager(vaultAddr?: string, githubToken?: string): VaultSecretManager {
//   if (!vaultManagerInstance) {
//     vaultManagerInstance = new VaultSecretManager(vaultAddr, githubToken);
//   }
//   return vaultManagerInstance;
// }

// /**
//  * Utility function to load secrets into environment variables
//  */
// export async function loadSecretsToEnv(secrets: Array<{ path: string; key: string; envVar?: string }>): Promise<void> {
//   const manager = getVaultManager();

//   for (const secret of secrets) {
//     try {
//       const value = await manager.getSecret(secret.path, secret.key);
//       const envVarName = secret.envVar || secret.key;

//       process.env[envVarName] = value;
//       console.log(`📝 Loaded ${envVarName} from Vault`);

//     } catch (error) {
//       console.warn(`⚠️  Failed to load ${secret.key} into environment:`, error);
//     }
//   }
// }