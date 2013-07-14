#!/usr/bin/perl

use lib qw(.);
use lib qw(./lib/perl5/site_perl/5.12.4/);
use lib qw(./lib/lib/perl5/site_perl/5.12.4);
use strict;
use Net::SFTP::Foreign;
use Digest::MD5;

sub commit {
    my $archivo = shift;
    my ($version, @replicas) = &getRep($archivo);
    &send2rep($archivo,$version+1,@replicas);
}

sub pull{
    my $archivo = shift;
    my $version = shift;
    my $checkL;
    my $checkR;
    my @arreglar;
    my $rep;

    if (defined($version)){
        print "error\n" unless (&versionOK($archivo,$version));
    }else{
        $version = &getVersion($archivo);
    }

    ($checkR,$rep,@arreglar) = &validarChecksum($archivo,$version);
    while ($checkR ne $checkL){
        &getFromRep($archivo,$version,$rep);
        $checkL = &checksum($archivo);
    }

    &arreglarRep($archivo,$version,@arreglar) if (@arreglar);
}

sub arreglarRep{
    my $archivo = shift;
    my $version = shift;
    my @replicas = @_;

    &send2rep($archivo,$version,@replicas);

}
# Rutina que calcula el checksum de un archivo
sub checksum{
    my $archivo = shift;
    my $checksum;
    eval{
        open(FILE, "/tmp/$archivo") or die "Can't find file $archivo\n";
        my $ctx = Digest::MD5->new;
        $ctx->addfile(*FILE);
        $checksum = $ctx->hexdigest;
        close(FILE);
    }; 
    return $checksum;
}

# Rutina que valida los checksum del archivo en todas las replicas
# Retorna el checksum valido y la replica a solicitar
# Si existe un error en alguno de los checksum reenvia el archivo a 
# la replica con el checksum incorrecto
sub validarChecksum{
    my $archivo = shift;
    my $version = shift;
    my @replicas =  &getRep($archivo);
    my %checksums;
    shift @replicas;
    foreach(@replicas){
        my $rep_url = "http://$_:" . PORT . '/RPC2';
        my $rep = Frontier::Client->new(url => $rep_url);
        my $result = $rep->call('rep.checksum',$archivo,$version);
        push (@{$checksums{$result}},$_);
    }

    my @modaCheck;
    my $moda;
    my @arreglar;
    while(my($check,@rep) = each %checksums){
        if (@modaCheck < @rep){
            if (@modaCheck){
                push(@arreglar,$_) foreach @modaCheck;
            }
            ($moda,@modaCheck) = ($check,@rep);
        }
    }
    return($moda,$modaCheck[0],@arreglar);
}


# Rutina que envia un archivo a la replica
# Parametros
# @servidores: lista de los servidores a los que se enviara el archivo
# $archivo: achivo que se enviara
sub send2rep{
    my $archivo = shift;
    my $version = shift;
    my @reps = @_;

    foreach(@reps){
        print "Enviando $archivo a $_";
        my $host = $_;
        my $sftp = Net::SFTP::Foreign->new(host=>$_, user=>'javier');
        $sftp->mkdir($raiz/$archivo);
        $sftp->put("/tmp/$archivo","$raiz/$archivo/$version");

        #   NOTIFICAR A TODO EL MUNDO EL ENVIO DE ARCHIVOS
        #   PARA QUE ACTUALICEN SU TABLA
        #my $rep_url = "http://$_:" . PORT . '/RPC2';
        #my $rep = Frontier::Client->new(url => $rep_url);
    }

    ## Multicast a todos notificando los cambios
}

# Rutina que recibe un archivo de una replica
# Parametros
# $archivo
# $version (la ultima por defecto)
# $replica
sub getFromRep{
    my $archivo = shift;
    my $rep = shift;
    my $version = shift;
    $version = &getVersion($archivo) unless defined($version);
    my $sftp = Net::SFTP::Foreign->new(host=>$rep, user=>'javier');
    $sftp->get("$raiz/$archivo/$version","/tmp/$archivo");

}

# Rutina que busca las replicas que tienen un archivo dado y la ultima version
# disponible 
sub getRep{
    my $archivo = shift;
    my $version = 0;
    my @replicas;
    while (my($pid, $rep) = each %tablaNodos) {
        my $arch = $rep->get($archivo); 
        if (defined($arch)){
            push(@replicas,$rep->nombre);
            $version = $arch->count;
        }
        @replicas = &lowRep if (!@replicas);
        return ($version,@replicas);
    }
}

# Rutina que busca las k replicas con menos carga
#
sub lowRep{
    my %cp;
    my @replicas;
    while (my($pid, $rep) = each %tablaNodos) {
        #   ARREGLAR TIENE QUE SER UN ARREGLO
        $cp{$rep->contar_archivos} = $rep->nombre;
    }  
    my @cargas = (sort keys %cp);

    #   FALTA DEFINIR LA CONSTANTE K
    for (my $i = 0; $i < K, $i++){
        push(@replicas, $cp{$cargas[$i]});
    }
    return @replicas;
}

# Rutina que retorna la ultima version de un archivo
sub getVersion{
    my $archivo = shift;
    my $version;
    while (my($pid, $rep) = each %tablaNodos) {
        my $arch = $rep->buscar_archivo($archivo); 
        if (defined($arch)){
            #   MODIFICAR SE NECESITA SABER EL NUMERO DE VERSIONES
            $version = $arch->contar_archivos();
            last;
        }
        return $version;
    }
}

#########
#Replica
#########
#

sub crearRaiz{
    mkdir $raiz;
}

sub wipe{
    system("rm -rf $raiz");
    &crearRaiz;
}

sub checksumRep{
    my $archivo = shift;
    my $version = shift;
    my $checksum;
    eval{
        open(FILE, "$raiz/$archivo") or die "Can't find file $archivo\n";
        my $ctx = Digest::MD5->new;
        $ctx->addfile(*FILE);
        $checksum = $ctx->hexdigest;
        close(FILE);
    }; 
    return $checksum;
}
