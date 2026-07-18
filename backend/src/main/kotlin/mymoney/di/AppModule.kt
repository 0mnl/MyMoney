package mymoney.di

import mymoney.config.AppConfig
import mymoney.config.DbConfig
import mymoney.config.JwtConfig
import mymoney.data.db.DatabaseFactory
import mymoney.data.repository.AccountRepositoryImpl
import mymoney.data.repository.FamilyMemberRepositoryImpl
import mymoney.data.repository.FamilyRepositoryImpl
import mymoney.data.repository.RefreshTokenRepositoryImpl
import mymoney.data.repository.UserRepositoryImpl
import mymoney.data.security.Argon2PasswordHasher
import mymoney.data.security.JwtTokenService
import mymoney.domain.repository.AccountRepository
import mymoney.domain.repository.FamilyMemberRepository
import mymoney.domain.repository.FamilyRepository
import mymoney.domain.repository.RefreshTokenRepository
import mymoney.domain.repository.UserRepository
import mymoney.domain.security.PasswordHasher
import mymoney.domain.security.TokenService
import mymoney.domain.usecase.account.ArchiveAccountUseCase
import mymoney.domain.usecase.account.CreateAccountUseCase
import mymoney.domain.usecase.account.DeleteAccountUseCase
import mymoney.domain.usecase.account.GetAccountUseCase
import mymoney.domain.usecase.account.ListAccountsUseCase
import mymoney.domain.usecase.account.UpdateAccountUseCase
import mymoney.domain.usecase.auth.LoginUseCase
import mymoney.domain.usecase.auth.LogoutAllUseCase
import mymoney.domain.usecase.auth.RefreshTokenUseCase
import mymoney.domain.usecase.auth.RegisterUserUseCase
import org.koin.dsl.module

fun appModule(config: AppConfig, databaseFactory: DatabaseFactory) = module {
    // Config
    single { config }
    single<DbConfig> { config.db }
    single<JwtConfig> { config.jwt }

    // Infra
    single { databaseFactory }
    single { databaseFactory.database }

    // Repositories
    single<FamilyRepository> { FamilyRepositoryImpl(get()) }
    single<FamilyMemberRepository> { FamilyMemberRepositoryImpl(get()) }
    single<UserRepository> { UserRepositoryImpl(get()) }
    single<RefreshTokenRepository> { RefreshTokenRepositoryImpl(get()) }
    single<AccountRepository> { AccountRepositoryImpl(get()) }

    // Security
    single<PasswordHasher> { Argon2PasswordHasher() }
    single<TokenService> { JwtTokenService(get()) }

    // Auth use cases
    single { RegisterUserUseCase(get(), get(), get(), get(), get(), get()) }
    single { LoginUseCase(get(), get(), get(), get(), get()) }
    single { RefreshTokenUseCase(get(), get(), get()) }
    single { LogoutAllUseCase(get()) }

    // Account use cases
    single { CreateAccountUseCase(get()) }
    single { ListAccountsUseCase(get()) }
    single { GetAccountUseCase(get()) }
    single { UpdateAccountUseCase(get()) }
    single { ArchiveAccountUseCase(get()) }
    single { DeleteAccountUseCase(get()) }
}
